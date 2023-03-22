package Play;

use v5.28;
use strict;

our @EXPORT = qw ( init play stop status connect_speaker volume_up volume_down check_connected_to_speaker );
use base qw(Exporter);

use lib "/home/pi/software";
use Utils;
use UserDetails;

use Vlc::Engine;
use List::Util;

my $player;
my $volume;

sub init {
  my $res = `bluetoothctl disconnect $speaker_mac`;           # make sure speaker is not connected else restart of bluetoothd will not happen in connect_speaker
  my $pa = `pulseaudio --start`;
  my $options = ["--no-video"];
  $player = Vlc::Engine->new($options);
  set_volume($speaker_vol);
}

# ret 1 if connected
sub check_connected_to_speaker {
  my $res = `bluetoothctl info $speaker_mac`;
  return 1 if index($res, "Connected: yes") != -1;
  return;
}

# connect to speaker
# return 1 if ok
sub connect_speaker {
  print_error("connecting to speaker mac = $speaker_mac");
  return 1 if check_connected_to_speaker() == 1;
  my $res = `sudo systemctl restart bluetooth`;                   # bluetoothd needs to be started after pulseaudio else no audio plays through speaker
  while (1) {
    $res = `journalctl --since=-1m -t bthelper -n 1 -r`;
    last if index($res, "Changing power on succeeded") != -1;
    print_error("waiting for bluetooth to restart");
    sleep 1;
  }
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
