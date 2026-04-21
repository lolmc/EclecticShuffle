package Plugins::EclecticShuffle::Schema;

use strict;
use warnings;

use DBI;
use File::Spec::Functions qw(catfile);
use Time::HiRes ();

use Slim::Utils::Log;
use Slim::Utils::Prefs;
use Slim::Utils::Timers;

use Plugins::EclecticShuffle::Plugin qw(
    WEIGHT_FLOOR WEIGHT_CAP COMPLETION_BONUS SKIP_PENALTY
);

my $log = Slim::Utils::Log->addLogCategory({
    'category'     => 'plugin.eclecticshuffle',
    'defaultLevel' => 'ERROR',
    'description'  => 'EclecticShuffle plugin',
});

my $server_prefs = preferences('server');

my $_dbh;
my $_fallback = 0;

use constant SCHEMA_VERSION => 1;
use constant PRUNE_DAYS     => 365;

# ---------------------------------------------------------------------------
# Public interface
# ---------------------------------------------------------------------------

# Called once from Plugin.pm initPlugin(). Sets up the DB and schedules prune.
# On any error, sets fallback mode — all subsequent calls are no-ops and the
# plugin delegates to LMS native shuffle.
sub init {
    my ($class) = @_;

    $_fallback = 0;

    my $ok = eval { _open_db(); 1 };
    if ( !$ok || $@ ) {
        $log->error("EclecticShuffle: DB init failed, using native shuffle fallback: $@");
        $_fallback = 1;
        return;
    }

    # Prune runs async on next event-loop tick so it never blocks LMS startup.
    Slim::Utils::Timers::setTimer(
        $class,
        Time::HiRes::time(),
        \&_run_prune,
    );
}

sub is_fallback { $_fallback }

# Record a play event. event_type is 'skip', 'completion', or 'partial'.
# Partial events are stored for potential v2 use but do not update track_weights.
sub record_event {
    my ( $class, $track_id, $player_id, $completion, $event_type ) = @_;
    return if $_fallback;

    my $dbh = _get_dbh() or return;
    eval {
        $dbh->do(
            q{INSERT INTO play_events
                (track_id, player_id, played_at, completion, event_type)
              VALUES (?, ?, strftime('%s','now'), ?, ?)},
            undef, $track_id, $player_id, $completion, $event_type,
        );
    };
    $log->error("record_event failed for $track_id: $@") if $@;
}

# Apply a weight delta to a track. delta is positive (completion) or negative (skip).
# Retries up to 3 times on SQLite BUSY before logging and discarding.
sub update_weight {
    my ( $class, $track_id, $delta ) = @_;
    return if $_fallback;

    my $attempts = 0;
    while ( $attempts < 3 ) {
        my $ok = eval {
            my $dbh = _get_dbh() or die "no db handle\n";

            my ($current) = $dbh->selectrow_array(
                'SELECT base_weight FROM track_weights WHERE track_id = ?',
                undef, $track_id,
            );

            my $new_weight = ( defined $current ? $current : 1.0 ) + $delta;
            $new_weight = WEIGHT_CAP   if $new_weight > WEIGHT_CAP;
            $new_weight = WEIGHT_FLOOR if $new_weight < WEIGHT_FLOOR;

            $dbh->do(
                q{INSERT OR REPLACE INTO track_weights
                    (track_id, base_weight, last_updated)
                  VALUES (?, ?, strftime('%s','now'))},
                undef, $track_id, $new_weight,
            );
            1;
        };
        last if $ok;

        $attempts++;
        if ( $attempts < 3 ) {
            Time::HiRes::sleep(0.01);
        }
        else {
            $log->error("update_weight failed after 3 attempts for $track_id: $@");
        }
    }
}

# Returns arrayref of hashrefs: [{track_id, base_weight, last_updated}, ...]
# Pre-filters to tracks with meaningful scores on the active horizon.
# Decay (base_weight * DECAY_FACTOR ^ days) is computed in Playlist.pm —
# SQLite 3.22 has no POWER() function so score cannot be calculated in SQL.
sub get_all_weights {
    my ($class) = @_;
    return [] if $_fallback;

    my $dbh = _get_dbh() or return [];

    my $rows = eval {
        $dbh->selectall_arrayref(
            q{SELECT track_id, base_weight, last_updated
              FROM track_weights
              WHERE base_weight > 0.2
                AND last_updated > (strftime('%s','now') - 63072000)},
            { Slice => {} },
        );
    };
    if ($@) {
        $log->error("get_all_weights failed: $@");
        return [];
    }
    return $rows // [];
}

# Count of distinct tracks with at least one non-partial event.
# Used by Playlist.pm to check the cold-start threshold.
# track_weights only gains rows from skip/completion events, so COUNT(*) is correct.
sub get_cold_start_count {
    my ($class) = @_;
    return 0 if $_fallback;

    my $dbh = _get_dbh() or return 0;
    my ($count) = eval {
        $dbh->selectrow_array('SELECT COUNT(*) FROM track_weights');
    };
    return $count // 0;
}

# Clear all learned weights and rebuild from surviving play_events.
# Called from Settings.pm Reset button.
sub reset_weights {
    my ($class) = @_;
    return if $_fallback;

    my $dbh = _get_dbh() or return;
    eval {
        $dbh->begin_work;
        _recalculate_from_events($dbh);
        $dbh->commit;
        $log->info("EclecticShuffle: weights reset");
    };
    if ($@) {
        eval { $dbh->rollback };
        $log->error("reset_weights failed: $@");
    }
}

# ---------------------------------------------------------------------------
# Private
# ---------------------------------------------------------------------------

sub _db_path {
    return catfile( $server_prefs->get('cachedir'), 'eclectic_shuffle.db' );
}

sub _open_db {
    my $path = _db_path();

    $_dbh = DBI->connect(
        "dbi:SQLite:dbname=$path", '', '',
        { RaiseError => 1, AutoCommit => 1, PrintError => 0 },
    ) or die "Cannot open DB at $path: " . DBI->errstr . "\n";

    $_dbh->do('PRAGMA journal_mode=WAL');
    _create_schema($_dbh);
    _check_schema_version($_dbh);
}

sub _get_dbh {
    # SQLite handles are file-based — ping is always true, but check definedness
    # in case init failed or was never called.
    return $_dbh if defined $_dbh;

    my $ok = eval { _open_db(); 1 };
    unless ($ok) {
        $log->error("EclecticShuffle: DB reconnect failed, switching to fallback: $@");
        $_fallback = 1;
        return undef;
    }
    return $_dbh;
}

sub _create_schema {
    my ($dbh) = @_;

    $dbh->do(q{
        CREATE TABLE IF NOT EXISTS schema_version (
            version INTEGER NOT NULL
        )
    });

    $dbh->do(q{
        CREATE TABLE IF NOT EXISTS play_events (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            track_id    TEXT    NOT NULL,
            player_id   TEXT    NOT NULL,
            played_at   INTEGER NOT NULL,
            completion  REAL    NOT NULL,
            event_type  TEXT    NOT NULL
        )
    });

    $dbh->do(q{
        CREATE TABLE IF NOT EXISTS track_weights (
            track_id     TEXT    PRIMARY KEY,
            base_weight  REAL    NOT NULL DEFAULT 1.0,
            last_updated INTEGER NOT NULL
        )
    });

    $dbh->do('CREATE INDEX IF NOT EXISTS idx_play_events_track ON play_events(track_id)');
    $dbh->do('CREATE INDEX IF NOT EXISTS idx_play_events_time  ON play_events(played_at)');

    my ($existing) = $dbh->selectrow_array('SELECT version FROM schema_version LIMIT 1');
    unless ( defined $existing ) {
        $dbh->do( 'INSERT INTO schema_version VALUES (?)', undef, SCHEMA_VERSION );
    }
}

sub _check_schema_version {
    my ($dbh) = @_;

    my ($version) = $dbh->selectrow_array('SELECT version FROM schema_version LIMIT 1');

    unless ( defined $version ) {
        $log->warn("EclecticShuffle: schema_version missing, assuming version 1");
        return;
    }
    if ( $version < SCHEMA_VERSION ) {
        # v1: no migrations yet. Future versions add upgrade steps here.
        $log->warn("EclecticShuffle: schema v$version < " . SCHEMA_VERSION . " — migration required");
    }
    if ( $version > SCHEMA_VERSION ) {
        $log->warn("EclecticShuffle: DB schema v$version > plugin version " . SCHEMA_VERSION . " — possible downgrade");
    }
}

sub _run_prune {
    my ($class) = @_;
    return if $_fallback;

    my $dbh = _get_dbh() or return;
    my $cutoff = time() - ( PRUNE_DAYS * 86400 );

    eval {
        $dbh->begin_work;
        $dbh->do( 'DELETE FROM play_events WHERE played_at < ?', undef, $cutoff );
        _recalculate_from_events($dbh);
        $dbh->commit;
        $log->info("EclecticShuffle: prune complete");
    };
    if ($@) {
        eval { $dbh->rollback };
        # Leave existing track_weights intact on prune failure.
        $log->error("EclecticShuffle: prune failed, existing weights preserved: $@");
    }
}

# Rebuild track_weights from surviving play_events.
#
# Known: this recalculation does not re-apply decay.
# Tracks capped/floored during live scoring may resurface briefly after a prune.
# Corrects itself within days via live scoring. Revisit if UAT surfaces
# 'weird post-restart behaviour'.
#
# The inline constants (COMPLETION_BONUS, SKIP_PENALTY, WEIGHT_FLOOR, WEIGHT_CAP)
# match the values in Plugin.pm. sprintf embeds them into SQL since SQLite
# aggregate functions do not accept bind parameters in CASE expressions.
sub _recalculate_from_events {
    my ($dbh) = @_;

    $dbh->do('DELETE FROM track_weights');

    my $sql = sprintf( q{
        INSERT INTO track_weights (track_id, base_weight, last_updated)
        SELECT
            track_id,
            MAX(%s, MIN(%s,
                1.0
                + SUM(CASE WHEN event_type = 'completion' THEN %s ELSE 0.0 END)
                - SUM(CASE WHEN event_type = 'skip'       THEN %s ELSE 0.0 END)
            )),
            MAX(played_at)
        FROM play_events
        WHERE event_type IN ('completion', 'skip')
        GROUP BY track_id
    }, WEIGHT_FLOOR, WEIGHT_CAP, COMPLETION_BONUS, SKIP_PENALTY );

    $dbh->do($sql);
}

1;
