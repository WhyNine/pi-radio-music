package UserDetails;

our @EXPORT = qw ( $path_to_pictures $plexUrl $plexToken $health_check_url $speaker_mac $speaker_vol);
use base qw(Exporter);
use strict;

use lib "/home/pi/doorbell";
use Utils;

use YAMC;

my $yamc = new YAMC();
$yamc->fileName('/home/pi/software/UserDetails.yml');

my $hash = $yamc->Read();
my %settings = %$hash;

our $path_to_pictures = $settings{"picture-path"};
#print_error("Path to pictures does not exist: $path_to_pictures") unless -e $path_to_pictures;

our $plexUrl = $settings{"plex-url"};
print_error("No Plex URL provided") unless $plexUrl;

our $plexToken = $settings{"plex-token"};
print_error("No Plex token provided") unless $plexToken;

our $health_check_url = $settings{"health-check-url"};

my $speaker = $settings{"speaker"};
our $speaker_mac = $$speaker{"mac"};
our $speaker_vol = $$speaker{"default-volume"};


1;
