use v5.28;
use strict;

use Vlc::Engine;

my $player;
  $player = Vlc::Engine->new();
$player->set_location('https://media-ssl.musicradio.com/Gold');
  $player->play();
  foreach (1 .. 30) {
    sleep(1);
    print($player->get_state());
  }
  print("\n");
