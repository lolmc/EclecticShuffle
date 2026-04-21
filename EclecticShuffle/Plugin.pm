package Plugins::EclecticShuffle::Plugin;

use strict;
use warnings;
use base qw(Slim::Plugin::Base);

use Exporter 'import';
use Scalar::Util qw(looks_like_number);
use Time::HiRes ();

use Slim::Control::Request;
use Slim::Utils::Log;
use Slim::Utils::Prefs;
use Slim::Utils::Timers;

use Plugins::EclecticShuffle::Schema;
use Plugins::EclecticShuffle::Scoring;
use Plugins::EclecticShuffle::Playlist;

# ---------------------------------------------------------------------------
# Constants — imported by Schema.pm, Scoring.pm, Playlist.pm
# ---------------------------------------------------------------------------

use constant {
    SKIP_PENALTY     => 0.5,
    COMPLETION_BONUS => 1.0,
    WEIGHT_FLOOR     => 0.1,
    WEIGHT_CAP       => 10.0,
    DECAY_FACTOR     => 0.977,   # half-life ~30 days
    COLD_START_MIN   => 20,      # distinct tracks before weighted mode activates
    QUEUE_REFILL_AT  => 5,       # top up when queue drops below this many remaining tracks
    QUEUE_BATCH_SIZE => 20,      # how many tracks to add per top-up
};

our @EXPORT_OK = qw(
    SKIP_PENALTY COMPLETION_BONUS WEIGHT_FLOOR WEIGHT_CAP
    DECAY_FACTOR COLD_START_MIN QUEUE_REFILL_AT QUEUE_BATCH_SIZE
);

my $log   = Slim::Utils::Log->addLogCategory({
    'category'     => 'plugin.eclecticshuffle',
    'defaultLevel' => 'ERROR',
    'description'  => 'EclecticShuffle',
});
my $prefs = preferences('plugin.eclecticshuffle');

# Per-player state: track currently playing, so we can score it when newsong fires.
# Key: player MAC address. Value: {track_id, player_id, start_time, duration}
my %_active_track;

# ---------------------------------------------------------------------------
# LMS plugin lifecycle
# ---------------------------------------------------------------------------

sub getDisplayName { 'PLUGIN_ECLECTICSHUFFLE' }

sub initPlugin {
    my ( $class, %args ) = @_;

    $prefs->init({
        adventurousness        => 5,
        eclectic_shuffle_active => 0,
    });

    $class->SUPER::initPlugin(%args);

    if (main::WEBUI) {
        require Plugins::EclecticShuffle::Settings;
        Plugins::EclecticShuffle::Settings->new($class);
    }

    Plugins::EclecticShuffle::Schema->init();

    # Subscribe to newsong to score the outgoing track and top up the queue.
    Slim::Control::Request::subscribe(
        \&_on_newsong,
        [['playlist'], ['newsong']],
    );

    # Subscribe to play/pause/stop to track session boundaries.
    Slim::Control::Request::subscribe(
        \&_on_playlist_cmd,
        [['playlist'], ['play', 'stop', 'pause', 'clear']],
    );

    $log->info("EclecticShuffle: plugin initialised");
}

sub shutdownPlugin {
    Slim::Control::Request::unsubscribe(\&_on_newsong);
    Slim::Control::Request::unsubscribe(\&_on_playlist_cmd);
}

# ---------------------------------------------------------------------------
# Activation helpers (called from Settings.pm)
# ---------------------------------------------------------------------------

sub start_eclectic_shuffle {
    my ( $class, $client ) = @_;
    return if Plugins::EclecticShuffle::Schema->is_fallback();

    $prefs->client($client)->set('eclectic_shuffle_active', 1);

    # Pre-fill queue immediately on start.
    Plugins::EclecticShuffle::Playlist->generate_and_inject($client);
    $log->info("EclecticShuffle: started for " . $client->id());
}

sub stop_eclectic_shuffle {
    my ( $class, $client ) = @_;
    $prefs->client($client)->set('eclectic_shuffle_active', 0);
    delete $_active_track{ $client->id() };
    $log->info("EclecticShuffle: stopped for " . $client->id());
}

sub is_active {
    my ( $class, $client ) = @_;
    return $prefs->client($client)->get('eclectic_shuffle_active') ? 1 : 0;
}

# ---------------------------------------------------------------------------
# Playback event handlers
# ---------------------------------------------------------------------------

sub _on_newsong {
    my ($request) = @_;
    my $client = $request->client() or return;
    my $player_id = $client->id();

    # Score the track that just ended before updating state.
    _score_outgoing_track($client, $player_id);

    # Record new track state.
    my $new_track_id = $client->currentTrackForClient()
        ? $client->currentTrackForClient()->url()
        : undef;
    my $new_duration = $client->currentTrackForClient()
        ? ( $client->currentTrackForClient()->secs() // 0 )
        : 0;

    $_active_track{$player_id} = {
        track_id  => $new_track_id,
        player_id => $player_id,
        start_time => Time::HiRes::time(),
        duration   => $new_duration,
    };

    return unless $class->is_active($client);

    # Top up the queue when it runs low.
    my $queue_remaining = scalar @{ $client->playlist() } - $client->streamingSongIndex() - 1;
    if ( $queue_remaining < QUEUE_REFILL_AT ) {
        Plugins::EclecticShuffle::Playlist->generate_and_inject($client);
    }
}

sub _on_playlist_cmd {
    my ($request) = @_;
    my $client = $request->client() or return;
    my $player_id = $client->id();
    my $cmd = $request->getRequest(1);

    if ( $cmd eq 'stop' || $cmd eq 'clear' ) {
        # Score whatever was playing, then clear state.
        _score_outgoing_track($client, $player_id);
        delete $_active_track{$player_id};
    }
}

# Score the track that was playing before the current event.
# Uses elapsed wall time vs. stored duration as the completion proxy.
sub _score_outgoing_track {
    my ( $client, $player_id ) = @_;

    my $state = $_active_track{$player_id} or return;
    my ( $track_id, $duration, $start_time ) =
        @{$state}{qw(track_id duration start_time)};

    return unless $track_id;

    # Discard event if duration is unknown (e.g. stream, network drop with no metadata).
    unless ( $duration && $duration > 0 ) {
        $log->debug("EclecticShuffle: skipping score for $track_id — duration unknown");
        return;
    }

    my $elapsed    = Time::HiRes::time() - $start_time;
    my $completion = $elapsed / $duration;
    $completion    = 1.0 if $completion > 1.0;

    my $event_type = classify_event($completion);

    Plugins::EclecticShuffle::Schema->record_event(
        $track_id, $player_id, $completion, $event_type,
    );

    # Partial events are stored but do not update weights.
    return if $event_type eq 'partial';

    Plugins::EclecticShuffle::Scoring->update_weight( $track_id, $event_type );
}

# ---------------------------------------------------------------------------
# Event classification — pure function, tested in t/events.t
# ---------------------------------------------------------------------------

sub classify_event {
    my ($completion) = @_;
    return 'skip'       if $completion < 0.20;
    return 'completion' if $completion >= 0.80;
    return 'partial';
}

1;
