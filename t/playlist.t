use strict;
use warnings;
use Test::More tests => 17;

# Test pure functions extracted from Playlist.pm.
# No LMS runtime needed — these are all mathematical.

use constant {
    DECAY_FACTOR     => 0.977,
    COLD_START_MIN   => 20,
    QUEUE_BATCH_SIZE => 20,
};

# ---------------------------------------------------------------------------
# Temperature formula
# ---------------------------------------------------------------------------

sub calculate_temperature {
    my ($slider) = @_;
    return 0.1 + ( $slider / 10.0 ) * 2.9;
}

ok( abs( calculate_temperature(1) - 0.39 ) < 0.001, 'T at slider=1' );
ok( abs( calculate_temperature(5) - 1.55 ) < 0.001, 'T at slider=5 (default)' );
ok( abs( calculate_temperature(9) - 2.71 ) < 0.001, 'T at slider=9' );

# ---------------------------------------------------------------------------
# Queue split formula
# ---------------------------------------------------------------------------

sub queue_split {
    my ($slider) = @_;
    use POSIX qw(floor);
    my $weighted = floor( QUEUE_BATCH_SIZE * ( 1 - $slider / 10 ) );
    my $random   = QUEUE_BATCH_SIZE - $weighted;
    return ($weighted, $random);
}

{
    my ($w, $r) = queue_split(0);
    is( $w, 20, 'slider=0: all weighted' );
    is( $r,  0, 'slider=0: no random' );
}
{
    my ($w, $r) = queue_split(5);
    is( $w, 10, 'slider=5: 10 weighted' );
    is( $r, 10, 'slider=5: 10 random' );
}
{
    my ($w, $r) = queue_split(10);
    is( $w,  0, 'slider=10: no weighted' );
    is( $r, 20, 'slider=10: all random' );
}

# ---------------------------------------------------------------------------
# Score decay
# ---------------------------------------------------------------------------

sub score {
    my ($base_weight, $days_since_last_play) = @_;
    return $base_weight * ( DECAY_FACTOR ** $days_since_last_play );
}

ok( abs( score(1.0, 0) - 1.0 ) < 0.001, 'score just played = base_weight' );
ok( score(1.0, 30) < 0.6 && score(1.0, 30) > 0.4, 'score at 30 days ≈ 0.5 (half-life)' );
ok( score(10.0, 0) == 10.0, 'high weight: no decay at day 0' );
ok( score(10.0, 730) < 0.01, 'high weight: near-zero after 2 years' );

# ---------------------------------------------------------------------------
# log-sum-exp softmax — overflow protection
# ---------------------------------------------------------------------------

sub log_sum_exp_draw_probs {
    my ($scores, $T) = @_;

    my @scaled = map { $_ / $T } @$scores;
    my $max_s  = $scaled[0];
    for (@scaled) { $max_s = $_ if $_ > $max_s }

    my @exp_shifted;
    my $sum_exp = 0;
    for my $s (@scaled) {
        my $e = exp( $s - $max_s );
        push @exp_shifted, $e;
        $sum_exp += $e;
    }
    return map { $_ / $sum_exp } @exp_shifted;
}

# Large values that would overflow plain exp()
{
    my @scores = (700, 600, 500);
    my $T = 1.0;
    my @probs = log_sum_exp_draw_probs(\@scores, $T);
    my $sum = 0; $sum += $_ for @probs;
    ok( abs($sum - 1.0) < 0.0001, 'log-sum-exp: probabilities sum to 1 (large values)' );
    ok( $probs[0] > $probs[1],    'log-sum-exp: highest score has highest prob' );
}

# Normal values
{
    my @scores = (2.0, 1.0, 0.5);
    my $T = 1.55;
    my @probs = log_sum_exp_draw_probs(\@scores, $T);
    my $sum = 0; $sum += $_ for @probs;
    ok( abs($sum - 1.0) < 0.0001, 'log-sum-exp: probabilities sum to 1 (normal values)' );
    ok( $probs[0] > $probs[2],    'log-sum-exp: higher score beats lower score' );
}
