package Plugins::EclecticShuffle::Settings;

use strict;
use warnings;
use base qw(Slim::Web::Settings);

use Slim::Utils::Log;
use Slim::Utils::Prefs;

use Plugins::EclecticShuffle::Plugin;
use Plugins::EclecticShuffle::Schema;

my $log   = Slim::Utils::Log->addLogCategory({
    'category'     => 'plugin.eclecticshuffle',
    'defaultLevel' => 'ERROR',
    'description'  => 'EclecticShuffle',
});
my $prefs = preferences('plugin.eclecticshuffle');

# ---------------------------------------------------------------------------
# Slim::Web::Settings interface
# ---------------------------------------------------------------------------

sub name { 'PLUGIN_ECLECTICSHUFFLE' }

sub page { 'plugins/EclecticShuffle/settings.html' }

# adventurousness is per-player so we save it manually in handler().
# Returning $prefs here gives Slim::Web::Settings a valid prefs object.
sub prefs { return ($prefs) }

sub handler {
    my ( $class, $client, $params ) = @_;

    # --- Handle action buttons ---

    my $action = $params->{action} // '';

    if ( $action eq 'start' && $client ) {
        Plugins::EclecticShuffle::Plugin->start_eclectic_shuffle($client);
    }
    elsif ( $action eq 'stop' && $client ) {
        Plugins::EclecticShuffle::Plugin->stop_eclectic_shuffle($client);
    }
    elsif ( $action eq 'reset' ) {
        Plugins::EclecticShuffle::Schema->reset_weights();
        $log->info("EclecticShuffle: weights reset via settings page");
    }

    # --- Save adventurousness (per-player pref) ---

    if ( defined $params->{adventurousness} && $client ) {
        my $val = int( $params->{adventurousness} );
        $val = 0  if $val < 0;
        $val = 10 if $val > 10;
        $prefs->client($client)->set( 'adventurousness', $val );
    }

    # --- Populate template variables ---

    my $cold_count  = Plugins::EclecticShuffle::Schema->get_cold_start_count();
    my $cold_min    = Plugins::EclecticShuffle::Plugin::COLD_START_MIN;
    my $is_fallback = Plugins::EclecticShuffle::Schema->is_fallback();
    my $active      = $client ? Plugins::EclecticShuffle::Plugin->is_active($client) : 0;
    my $slider      = $client ? ( $prefs->client($client)->get('adventurousness') // 5 ) : 5;

    if ($is_fallback) {
        $params->{eclectic_status_key} = 'PLUGIN_ECLECTICSHUFFLE_STATUS_FALLBACK';
        $params->{eclectic_status_arg} = '';
    }
    elsif ( !$active ) {
        $params->{eclectic_status_key} = 'PLUGIN_ECLECTICSHUFFLE_STATUS_INACTIVE';
        $params->{eclectic_status_arg} = '';
    }
    elsif ( $cold_count < $cold_min ) {
        $params->{eclectic_status_key} = 'PLUGIN_ECLECTICSHUFFLE_STATUS_LEARNING';
        $params->{eclectic_status_arg} = "$cold_count/$cold_min";
    }
    else {
        $params->{eclectic_status_key} = 'PLUGIN_ECLECTICSHUFFLE_STATUS_ACTIVE';
        $params->{eclectic_status_arg} = $cold_count;
    }

    $params->{eclectic_active}      = $active;
    $params->{eclectic_slider}      = $slider;
    $params->{eclectic_is_fallback} = $is_fallback ? 1 : 0;

    return $class->SUPER::handler( $client, $params );
}

1;
