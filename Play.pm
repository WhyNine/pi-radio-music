package Play;

use v5.28;
use strict;

our @EXPORT = qw ( init play stop status connect_speaker volume_up volume_down );
use base qw(Exporter);

use lib "/home/pi/software";
use Utils;
use UserDetails;

use Vlc::Engine;
use List::Util;

my $player;
my $volume;

sub init {
  my $pa = `pulseaudio --start`;
  $player = Vlc::Engine->new();
  set_volume($speaker_vol);
}

# connect to speaker
# return 1 if ok
sub connect_speaker {
  print_error("connecting to speaker mac = $speaker_mac");
  my $res = `bluetoothctl info $speaker_mac`;
  print_error("connection to speaker: $res");
  return 1 if index($res, "Connected: yes") != -1;
  $res = `bluetoothctl connect $speaker_mac`;
  print_error("result = $res");
  if (index($res, "Connection successful") != -1) {
    print_error("Bluetooth connection successful");
    return 1;
  }
}

sub play {
  my $url = shift;
  $player->stop();
  #print_error("url = $url");
  if (substr($url, 0, 4) eq "http") {
    $player->set_location($url);
  } else {
    $player->set_media($url);
  }
  $player->play();
  set_volume($volume);
}

sub stop {
  $player->stop() if $player;
}

sub set_volume {
  $volume = shift;
  print_error("volume set to $volume");
  $player->set_volume($volume);
}

sub volume_up {
  set_volume(List::Util::min(100, $volume + 5));
}

sub volume_down {
  set_volume(List::Util::max(5, $volume - 5));
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
