use strict;
use warnings;
use Test::More tests => 10;

# Test the weight clamping arithmetic directly.
# These constants must match Plugin.pm — if you change the algorithm, update here.
use constant {
    SKIP_PENALTY     => 0.5,
    COMPLETION_BONUS => 1.0,
    WEIGHT_FLOOR     => 0.1,
    WEIGHT_CAP       => 10.0,
};

sub apply_delta {
    my ($current, $delta) = @_;
    my $new = $current + $delta;
    $new = WEIGHT_CAP   if $new > WEIGHT_CAP;
    $new = WEIGHT_FLOOR if $new < WEIGHT_FLOOR;
    return $new;
}

# Neutral start
is( apply_delta(1.0, +COMPLETION_BONUS), 2.0, 'completion from neutral: 1.0 -> 2.0' );
is( apply_delta(1.0, -SKIP_PENALTY),     0.5, 'skip from neutral: 1.0 -> 0.5' );

# Cap enforcement
is( apply_delta(10.0, +COMPLETION_BONUS), 10.0, 'completion at cap stays at 10.0' );
is( apply_delta(9.5,  +COMPLETION_BONUS), 10.0, 'completion nudges to cap exactly' );

# Floor enforcement
is( apply_delta(0.1, -SKIP_PENALTY),  0.1, 'skip at floor stays at 0.1' );
is( apply_delta(0.4, -SKIP_PENALTY),  0.1, 'skip below floor clamps to 0.1' );

# Post-prune recalculation formula: clamp(1.0 + completions - 0.5*skips, 0.1, 10.0)
sub recalc_weight {
    my ($completions, $skips) = @_;
    my $w = 1.0 + ($completions * COMPLETION_BONUS) - ($skips * SKIP_PENALTY);
    $w = WEIGHT_CAP   if $w > WEIGHT_CAP;
    $w = WEIGHT_FLOOR if $w < WEIGHT_FLOOR;
    return $w;
}

is( recalc_weight(5,  0),  6.0, 'recalc: 5 completions, 0 skips' );
is( recalc_weight(0,  4),  0.1, 'recalc: 0 completions, 4 skips => floor' );
is( recalc_weight(15, 0), 10.0, 'recalc: many completions => cap' );
is( recalc_weight(3,  2),  3.0, 'recalc: 3 completions, 2 skips: 1+3-1=3' );
