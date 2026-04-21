package Plugins::EclecticShuffle::Playlist;

use strict;
use warnings;

use List::Util   qw(shuffle);
use POSIX        qw(floor);

use Slim::Control::Request;
use Slim::Utils::Log;
use Slim::Utils::Prefs;

use Plugins::EclecticShuffle::Plugin qw(
    DECAY_FACTOR COLD_START_MIN QUEUE_BATCH_SIZE
);
use Plugins::EclecticShuffle::Schema;

my $log   = Slim::Utils::Log->addLogCategory({
    'category'     => 'plugin.eclecticshuffle',
    'defaultLevel' => 'ERROR',
    'description'  => 'EclecticShuffle',
});
my $prefs = preferences('plugin.eclecticshuffle');

# ---------------------------------------------------------------------------
# Public interface
# ---------------------------------------------------------------------------

# Generate a batch of tracks and append them to the player queue.
# Falls back to LMS native shuffle when below cold-start threshold or on error.
sub generate_and_inject {
    my ( $class, $client ) = @_;

    my $tracks = eval { $class->generate_queue($client) };
    if ( $@ || !@{ $tracks // [] } ) {
        $log->warn("EclecticShuffle: queue generation failed, using native shuffle: $@");
        _inject_native( $client, QUEUE_BATCH_SIZE );
        return;
    }

    _inject_tracks( $client, $tracks );
}

# Returns arrayref of track URLs. Does not write to queue.
# Called by generate_and_inject and directly testable.
sub generate_queue {
    my ( $class, $client ) = @_;

    my $slider = $prefs->client($client)->get('adventurousness') // 5;

    # Cold-start: fall back to native shuffle until enough play history exists.
    my $cold_count = Plugins::EclecticShuffle::Schema->get_cold_start_count();
    if ( $cold_count < COLD_START_MIN ) {
        $log->debug("EclecticShuffle: cold start ($cold_count/" . COLD_START_MIN . ")");
        return _native_random_tracks( $client, QUEUE_BATCH_SIZE, {} );
    }

    my @current_queue = @{ _current_queue_urls($client) };
    my %exclude = map { $_ => 1 } @current_queue;

    # Split batch into weighted (history-driven) and random (discovery) portions.
    #
    #   slider=0  → 100% weighted,  0% random  (pure preference)
    #   slider=5  →  50% weighted, 50% random  (default: balanced)
    #   slider=10 →   0% weighted, 100% random (pure exploration)
    #
    my $weighted_count = floor( QUEUE_BATCH_SIZE * ( 1 - $slider / 10 ) );
    my $random_count   = QUEUE_BATCH_SIZE - $weighted_count;

    my @weighted_tracks;
    if ( $weighted_count > 0 ) {
        my $candidates = Plugins::EclecticShuffle::Schema->get_all_weights();
        @weighted_tracks = @{ _softmax_sample(
            $candidates, $weighted_count, $slider, \%exclude,
        ) };
        $exclude{$_} = 1 for @weighted_tracks;
    }

    my @random_tracks;
    if ( $random_count > 0 ) {
        my $got = _native_random_tracks( $client, $random_count, \%exclude );
        @random_tracks = @$got;
    }

    # If native fetch failed, fill remaining slots from weighted pool.
    if ( @random_tracks < $random_count && $weighted_count < QUEUE_BATCH_SIZE ) {
        my $shortfall = $random_count - scalar @random_tracks;
        $log->warn("EclecticShuffle: native random fetch short by $shortfall, padding with weighted");
        my $candidates = Plugins::EclecticShuffle::Schema->get_all_weights();
        my $extra = _softmax_sample( $candidates, $shortfall, $slider, \%exclude );
        push @random_tracks, @$extra;
    }

    return [ shuffle( @weighted_tracks, @random_tracks ) ];
}

# ---------------------------------------------------------------------------
# Softmax sampling — pure functions, tested in t/playlist.t
# ---------------------------------------------------------------------------

# Sample $n track URLs from $candidates using softmax probabilities.
# $candidates: arrayref of {track_id, base_weight, last_updated}
# $n:          how many to draw (without replacement)
# $slider:     adventurousness 0-10 (0 = deterministic top-N)
# $exclude:    hashref of track_ids to skip
#
# Queue generation pipeline:
#
#   candidates [{track_id, base_weight, last_updated}]
#        │
#        ├─ exclude tracks in $exclude
#        ├─ score = base_weight * DECAY_FACTOR ^ days_since_last_play
#        │
#        ├─ slider = 0 → sort by score desc, take top $n
#        └─ slider 1–9 → log-sum-exp softmax, draw $n without replacement
#
sub _softmax_sample {
    my ( $candidates, $n, $slider, $exclude ) = @_;
    $exclude //= {};

    my $now = time();

    # Decay each candidate's base_weight by how long ago it was last played.
    my @scored;
    for my $c (@$candidates) {
        next if $exclude->{ $c->{track_id} };
        my $days  = ( $now - $c->{last_updated} ) / 86400;
        my $score = $c->{base_weight} * ( DECAY_FACTOR ** $days );
        push @scored, { track_id => $c->{track_id}, score => $score };
    }

    return [] unless @scored;

    # Return as many as possible if pool is smaller than requested.
    $n = scalar @scored if $n > scalar @scored;

    # Slider = 0: deterministic top-N.
    if ( $slider == 0 ) {
        my @sorted = sort { $b->{score} <=> $a->{score} } @scored;
        return [ map { $_->{track_id} } @sorted[ 0 .. ( $n - 1 ) ] ];
    }

    # Slider 1–9: softmax with temperature T.
    # T = 0.1 (slider=1, near-deterministic) .. 2.9 (slider=9, near-uniform)
    my $T = 0.1 + ( $slider / 10.0 ) * 2.9;

    my @selected;
    my %used;

    for ( 1 .. $n ) {
        my @pool = grep { !$used{ $_->{track_id} } } @scored;
        last unless @pool;
        my $chosen = _log_sum_exp_draw( \@pool, $T );
        push @selected, $chosen;
        $used{$chosen} = 1;
    }

    return \@selected;
}

# Draw one track_id from @pool using log-sum-exp softmax probabilities.
#
# Standard softmax exp(s/T) overflows for s/T > ~709 in 64-bit floats.
# log-sum-exp shifts all values by max_s before exponentiating, preventing overflow:
#
#   max_s   = max(score_i / T)
#   log_sum = log( sum( exp(score_i/T - max_s) ) ) + max_s
#   P(i)    = exp(score_i/T - log_sum)
#
sub _log_sum_exp_draw {
    my ( $pool, $T ) = @_;

    my @scaled = map { $_->{score} / $T } @$pool;

    # Find max for numerical stability.
    my $max_s = $scaled[0];
    for (@scaled) { $max_s = $_ if $_ > $max_s }

    my @exp_shifted;
    my $sum_exp = 0;
    for my $s (@scaled) {
        my $e = exp( $s - $max_s );
        push @exp_shifted, $e;
        $sum_exp += $e;
    }

    # Cumulative draw.
    my $rand       = rand();
    my $cumulative = 0;
    for my $i ( 0 .. $#$pool ) {
        $cumulative += $exp_shifted[$i] / $sum_exp;
        return $pool->[$i]{track_id} if $rand <= $cumulative;
    }

    # Floating-point rounding fallback: return last entry.
    return $pool->[-1]{track_id};
}

# ---------------------------------------------------------------------------
# LMS queue helpers
# ---------------------------------------------------------------------------

sub _current_queue_urls {
    my ($client) = @_;
    return [ map { $_->url() } @{ $client->playlist() // [] } ];
}

# Fetch up to $n random tracks from the LMS library, excluding $exclude hashref.
# Uses LMS 'tracks' CLI query with sort:random.
# Returns empty arrayref on failure — caller handles the shortfall.
sub _native_random_tracks {
    my ( $client, $n, $exclude ) = @_;
    $exclude //= {};

    my @tracks;
    eval {
        # Fetch extra to account for exclusions.
        my $request = Slim::Control::Request::executeRequest(
            $client, [ 'tracks', 0, $n * 3, 'sort:random' ],
        );
        my $loop = $request->getResult('titles_loop') // [];
        for my $item (@$loop) {
            my $url = $item->{url} or next;
            next if $exclude->{$url};
            push @tracks, $url;
            last if @tracks >= $n;
        }
    };
    if ($@) {
        $log->warn("EclecticShuffle: LMS random track fetch failed: $@");
    }
    return \@tracks;
}

sub _inject_tracks {
    my ( $client, $track_urls ) = @_;
    for my $url (@$track_urls) {
        Slim::Control::Request::executeRequest(
            $client, [ 'playlist', 'add', $url ],
        );
    }
}

sub _inject_native {
    my ( $client, $n ) = @_;
    my $tracks = _native_random_tracks( $client, $n, {} );
    _inject_tracks( $client, $tracks ) if @$tracks;
}

1;
