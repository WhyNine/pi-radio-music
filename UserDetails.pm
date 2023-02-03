package UserDetails;

our @EXPORT = qw ( $plexUrl $plexToken $speaker_mac $speaker_vol $GREEN_BTN $RED_BTN $YELLOW_BTN $BLUE_BTN $backlight_pin $backlight_on_level $backlight_off_level );
use base qw(Exporter);
use strict;

use lib "/home/pi/doorbell";
use Utils;

use YAMC;

my $yamc = new YAMC();
$yamc->fileName('/home/pi/software/UserDetails.yml');

# This YAML file is expected to contain:
# plex-token: <token for Plex server>
# plex-url: "http://<plex server name or IP address>:32400"
# speaker:
#   mac: <mac address of bluetooth speaker>
#   default-volume: <default volume level between 0 and 100>

my $hash = $yamc->Read();
my %settings = %$hash;

our $plexUrl = $settings{"plex-url"};
print_error("No Plex URL provided") unless $plexUrl;

our $plexToken = $settings{"plex-token"};
print_error("No Plex token provided") unless $plexToken;

my $speaker = $settings{"speaker"};
our $speaker_mac = $$speaker{"mac"};
our $speaker_vol = $$speaker{"default-volume"};

my $gpio = $settings{"pi-pins"};
our $GREEN_BTN = $$gpio{"green"};
our $RED_BTN = $$gpio{"red"};
our $YELLOW_BTN = $$gpio{"yellow"};
our $BLUE_BTN = $$gpio{"blue"};
our $backlight_pin = $$gpio{"backlight"};

my $backlight = $settings{"backlight"};
our $backlight_on_level = $$backlight{"on"};
our $backlight_off_level = $$backlight{"off"};


1;
