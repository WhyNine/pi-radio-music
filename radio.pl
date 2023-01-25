# screen is 160 x 128
# buttons:
#  green = play / select / ok / next
#  red = stop / back / cancel
#  yellow = up
#  blue = down

use strict;
use v5.28;

use lib "/home/pi/software";
use Graphics;
use Input;
use Utils;
use Play;

use Time::HiRes;
#use JSON::Parse;
use RPi::PIGPIO ':all';                       # can't use RPi::Pin because pwm requires sudo

# Possible screens (see visio):
# - radio menu
# - radio connecting
# - radio playing
# - playlist menu
# - playlist connecting
# - playlist playing

my @radio_menu_items = ({"text" => "Radio 2", "icon" => "radio-2-small.png", "url" => 'http://dvbadmin:dvbadmin@tvheadend:9981/stream/channelid/526472930', "image" => "BBC_Radio_2_large.png"}, 
                        {"text" => "Radio 4", "icon" => "radio-4-small.png", "url" => 'http://dvbadmin:dvbadmin@tvheadend:9981/stream/channelid/183185977', "image" => "BBC_Radio_4_large.png"}, 
                        {"text" => "Gold radio", "icon" => "gold_small.png", "url" => "https://media-ssl.musicradio.com/Gold", "image" => "gold_large.png"},
                        {"text" => "Greatest Hits", "icon" => "greatest-hits-radio-small.png", "url" => 'http://dvbadmin:dvbadmin@tvheadend:9981/stream/channel/a923c73e007d4625a5c90c4db8648a1a', "image" => "greatest-hits-radio-large.png"});
my %radio_menu_labels = ("green label" => "Play", "red label" => "Playlist", "arrows" => 1, "heading" => "Radio");
my %radio_menu = ("items" => \@radio_menu_items, "details" => \%radio_menu_labels, "highlight" => 0);
my %radio_menu_btns = ("green" => \&display_radio_connecting, "red" => \&update_radio_menu, "blue" => \&update_radio_menu, "yellow" => \&update_radio_menu);

my %radio_connecting_labels = ("red label" => "Cancel", "heading" => "Radio");
my %radio_connecting = ("text" => "Connecting ...", "details" => \%radio_connecting_labels);
my %radio_connecting_btns = ("red" => \&display_radio_menu);

my %radio_playing_labels = ("red label" => "Stop", "heading" => "Playing");
my %radio_playing_btns = ("red" => \&display_radio_menu);
my %radio_playing = ("details" => \%radio_playing_labels);             # hash "station ref" added dynamically to point at station being played

my %playlist_menu_labels = ("green label" => "Play", "red label" => "Radio", "arrows" => 1, "heading" => "Playlists");

my %playlist_connecting_labels = ("red label" => "Cancel", "heading" => "Playlists");

my %playlist_playing_labels = ("green label" => "Skip", "red label" => "Stop", "heading" => "Playing");


my $pigpio;
my $button_subs;               # ref to hash of colours -> functions
my $loop_sub;                  # ref to function to run every main loop
my $time_last_button_pressed;

# <playlist title> -> ref to hash of
#   thumbnail -> url of thumbnail for playlist
#   tracks -> ref to array of ref to hash of
#     thumbnail -> url of thumbnail for track
#     album_title -> title of album track is from
#     track_title -> title of track
#     artist_name -> name of artist
#     duration -> track length in ms
#     url -> url of media file
my %playlists;

#---------------------------------------------------------------------------------------------------
sub backlight {
  state $backlight_pin = 12;
  state $on_time = 0;
  state $dimmed = 0;
  $pigpio->set_mode($backlight_pin, RPi::PIGPIO::PI_OUTPUT);
  my $arg = shift;
  if ($arg eq "on") {
    #log_value(\$mqtt_instance, "Backlight on", "Main");
    $pigpio->write_pwm($backlight_pin, 50);
    $on_time = time();
    $dimmed = 0;
  }
  if ($arg eq "off") {
    if ((!$dimmed) && ((time() - $on_time) > 60)) {
      #log_value(\$mqtt_instance, "Backlight off", "Main");
      $pigpio->write_pwm($backlight_pin, 230);
      $dimmed = 1;
    }
  }
}

sub init {
  init_graphics();
  $pigpio = RPi::PIGPIO->connect('127.0.0.1');
  print_error("Unable to connect to pigpiod", "Main") if (!$pigpio->connected());
  backlight("on");
}

sub check_for_button {
  Input::monitor_buttons();
  if ($pressed_time != $time_last_button_pressed) {
    $time_last_button_pressed = $pressed_time;
    return $pressed_key;
  }
}

sub null_sub {
}

#---------------------------------------------------------------------------------------------------
sub display_radio_menu {
  Play::stop();
  print_radio_menu(\%radio_menu);
  $button_subs = \%radio_menu_btns;
  $loop_sub = \&null_sub;
}

sub display_radio_connecting {
  print_radio_connecting(\%radio_connecting);
  $button_subs = \%radio_connecting_btns;
  $loop_sub = \&radio_connecting_monitor;
  Play::play($radio_menu_items[$radio_menu{"highlight"}]->{"url"});
}

sub radio_connecting_monitor {
  my $state = Play::status();
  print_error("state = $state");
  if ($state eq "Playing") {
    display_radio_playing();
  } elsif (($state ne "Opening") && ($state ne "Buffering") && ($state ne "Paused")) {
    display_radio_menu();
  }
}

sub display_radio_playing {
  $radio_playing{"station ref"} = $radio_menu_items[$radio_menu{"highlight"}];
  print_radio_playing(\%radio_playing);
  $button_subs = \%radio_playing_btns;
  $loop_sub = \&radio_playing_monitor;
}

sub radio_playing_monitor {
  my $state = Play::status();
  #print_error("state = $state");
  if (($state eq 'Paused') || ($state eq 'Opening') || ($state eq 'Buffering')) {
    print_error("state = $state");
    display_radio_connecting();
  } elsif (($state eq 'Stopped') || ($state eq 'Ended') || ($state eq 'Error')) {
    print_error("state = $state");
    display_radio_menu();
  }
}

sub update_radio_menu {
  my $btn = shift;
  if ($btn eq "yellow") {                   # up
    return if $radio_menu{"highlight"} == 0;
    $radio_menu{"highlight"}--;
    print_menu_items($radio_menu{"items"}, $radio_menu{"highlight"});
    return;
  }
  if ($btn eq "blue") {                     # down
    return if $radio_menu{"highlight"} == scalar(@{$radio_menu{"items"}}) - 1;
    $radio_menu{"highlight"}++;
    print_menu_items($radio_menu{"items"}, $radio_menu{"highlight"});
    return;
  }
}

#---------------------------------------------------------------------------------------------------
sub display_playlist_menu {
  print_radio_connecting(\%radio_menu);
  $button_subs = \%radio_menu_btns;
}

#---------------------------------------------------------------------------------------------------

#---------------------------------------------------------------------------------------------------
init();
display_radio_menu();
Input::init();
Play::init();


my $key;
while (1) {
  $loop_sub->();
  if ($key = check_for_button()) {
    #print_error("$key pressed");
    if (defined $button_subs->{$key}) {
      $button_subs->{$key}->($key);
    }
  }
  Time::HiRes::sleep(0.1);
}