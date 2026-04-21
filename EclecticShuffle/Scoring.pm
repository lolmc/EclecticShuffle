package Plugins::EclecticShuffle::Scoring;

use strict;
use warnings;

use Plugins::EclecticShuffle::Plugin  qw(COMPLETION_BONUS SKIP_PENALTY);
use Plugins::EclecticShuffle::Schema;

# Apply a weight delta to a track based on the event type.
# Delegates clamping and persistence to Schema.
sub update_weight {
    my ( $class, $track_id, $event_type ) = @_;

    my $delta = $event_type eq 'completion' ?  COMPLETION_BONUS
              : $event_type eq 'skip'       ? -SKIP_PENALTY
              : return;  # 'partial' — no weight update

    Plugins::EclecticShuffle::Schema->update_weight( $track_id, $delta );
}

1;
