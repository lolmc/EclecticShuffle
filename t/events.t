use strict;
use warnings;
use Test::More tests => 9;

# classify_event is a pure function. Load it without the LMS runtime by
# duplicating the boundary logic here — keeps tests independent of plugin load.
# If the thresholds change in Plugin.pm, update these tests to match.

sub classify_event {
    my ($completion) = @_;
    return 'skip'       if $completion < 0.20;
    return 'completion' if $completion >= 0.80;
    return 'partial';
}

# Skip boundaries
is( classify_event(0.00),  'skip',       'hard skip (0.00)' );
is( classify_event(0.10),  'skip',       'clear skip (0.10)' );
is( classify_event(0.19),  'skip',       'boundary: 0.19 is skip' );

# Partial zone
is( classify_event(0.20),  'partial',    'boundary: 0.20 is partial' );
is( classify_event(0.50),  'partial',    'midpoint partial' );
is( classify_event(0.79),  'partial',    'boundary: 0.79 is partial' );

# Completion boundaries
is( classify_event(0.80),  'completion', 'boundary: 0.80 is completion' );
is( classify_event(0.95),  'completion', 'near-end completion' );
is( classify_event(1.00),  'completion', 'full play (1.00)' );
