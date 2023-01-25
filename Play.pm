package Play;

use v5.28;
use strict;

our @EXPORT = qw ( init play stop status);
use base qw(Exporter);

use lib "/home/pi/software";
use Utils;

use Vlc::Engine;

my $player;

# use `bluetoothctl connect 00:E0:4C:A9:8D:1C` to connect to speaker
# output is:
#Attempting to connect to 00:E0:4C:A9:8D:1C
#[CHG] Device 00:E0:4C:A9:8D:1C Connected: yes
#Connection successful

sub init {
  $player = Vlc::Engine->new();
}

sub play {
  my $url = shift;
  $player->stop();
  print_error("url = $url");
  $player->set_location($url);
  $player->play();
}

sub stop {
  $player->stop() if $player;
}

# 0: 'NothingSpecial',
# 1: 'Opening',
# 2: 'Buffering',
# 3: 'Playing',
# 4: 'Paused',
# 5: 'Stopped',
# 6: 'Ended',
# 7: 'Error'
my @states = ('NothingSpecial', 'Opening', 'Buffering', 'Playing', 'Paused', 'Stopped', 'Ended', 'Error');
sub status {
  return $states[$player->get_state()] if $player;
}

1;
