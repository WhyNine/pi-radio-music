# screen is 160 x 128
# buttons:
#  green = play / select / ok / next
#  red = stop / back / cancel
#  yellow = up
#  blue = down

# I tried using Events and IPC::MPS but they both interfered with vlc. mpg123 won't play all the both radio and songs.

use strict;
use v5.28;

use lib "/home/pi/software";
use Graphics;
use Input;
use Utils;
use Play;
use UserDetails;

use Time::HiRes;
use RPi::PIGPIO ':all';                       # can't use RPi::Pin because pwm requires sudo
use LWP::UserAgent;
use HTTP::Request;
use JSON::Parse qw(parse_json_safe);
use File::Path;
use File::Basename;
use URI::Encode;

# Possible screens (see visio):
# - radio menu
# - radio connecting
# - radio playing
# - playlist menu
# - playlist connecting
# - playlist playing

# array of refs to hash of:
#   text -> title of playlist
#   image -> url of thumbnail for playlist
#   tracks -> ref to array of ref to hash of
#     thumbnail -> url of thumbnail for track
#     album_title -> title of album track is from
#     track_title -> title of track
#     artist_name -> name of artist
#     duration -> track length in ms
#     url -> url of media file
my @playlist_menu_items = ();
my %playlist_menu_labels = ("green label" => "Play", "red label" => "Radio", "arrows" => 1, "heading" => "Playlists");
my %playlist_menu = ("items" => \@playlist_menu_items, "details" => \%playlist_menu_labels, "highlight" => 0);
my %playlist_menu_btns = ("green" => \&display_playlist_connecting, "red" => \&display_radio_menu, "blue" => \&update_playlist_menu, "yellow" => \&update_playlist_menu);

my %playlist_connecting_labels = ("red label" => "Cancel", "heading" => "Playlists");
my %playlist_connecting = ("text" => "Connecting ...", "details" => \%playlist_connecting_labels);
my %playlist_connecting_btns = ("red" => \&display_playlist_menu);

my %playlist_playing_labels = ("green label" => "Skip", "red label" => "Stop", "heading" => "Playing", "arrows" => 2);
my %playlist_playing_btns = ("green" => \&playlist_playing_next, "red" => \&display_playlist_menu, "blue" => \&Play::volume_down, "yellow" => \&Play::volume_up);
my %playlist_playing = ("details" => \%playlist_playing_labels, "track info" => \%playlist_menu);

my @radio_menu_items = ({"text" => "Radio 2", "icon" => "radio-2-small.png", "url" => 'http://dvbadmin:dvbadmin@tvheadend:9981/stream/channelid/526472930', "image" => "BBC_Radio_2_large.png"}, 
                        {"text" => "Radio 4", "icon" => "radio-4-small.png", "url" => 'http://dvbadmin:dvbadmin@tvheadend:9981/stream/channelid/183185977', "image" => "BBC_Radio_4_large.png"}, 
                        {"text" => "Gold radio", "icon" => "gold_small.png", "url" => "https://media-ssl.musicradio.com/Gold", "image" => "gold_large.png"},
                        {"text" => "Greatest Hits", "icon" => "greatest-hits-radio-small.png", "url" => 'http://dvbadmin:dvbadmin@tvheadend:9981/stream/channel/a923c73e007d4625a5c90c4db8648a1a', "image" => "greatest-hits-radio-large.png"});
my %radio_menu_labels = ("green label" => "Play", "red label" => "Playlist", "arrows" => 1, "heading" => "Radio");
my %radio_menu = ("items" => \@radio_menu_items, "details" => \%radio_menu_labels, "highlight" => 0);
my %radio_menu_btns = ("green" => \&display_radio_connecting, "red" => \&display_playlist_menu, "blue" => \&update_radio_menu, "yellow" => \&update_radio_menu);

my %radio_connecting_labels = ("red label" => "Cancel", "heading" => "Radio");
my %radio_connecting = ("text" => "Connecting ...", "details" => \%radio_connecting_labels);
my %radio_connecting_btns = ("red" => \&display_radio_menu);

my %radio_playing_labels = ("red label" => "Stop", "heading" => "Playing", "arrows" => 2);
my %radio_playing_btns = ("red" => \&display_radio_menu, "blue" => \&Play::volume_down, "yellow" => \&Play::volume_up);
my %radio_playing = ("details" => \%radio_playing_labels);             # hash "station ref" added dynamically to point at station being played

my %initialising_labels = ("heading" => "Initialising");
my %initialising = ("text" => "Please wait ...", "details" => \%initialising_labels);

my $pigpio;
my $button_subs;               # ref to hash of colours -> functions
my $loop_sub;                  # ref to function to run every main loop
my $time_last_button_pressed;

my @tokens = ("X-Plex-Product" => "Radio and music player",
              "X-Plex-Version" => "1.0",
              "X-Plex-platform" => "RaspberryPi",
              "X-Plex-platformVersion" => "3",
              "X-Plex-device" => "radio",
              "X-Plex-model" => "radio",
              'X-Plex-Client-Identifier' => "radiomusicplayer",
              "X-Plex-Token" => $plexToken,
              'Accept' => 'application/json',
              "User-Agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:100.0) Gecko/20100101 Firefox/100.0");	
my $plexParams;

#---------------------------------------------------------------------------------------------------
sub backlight {
  state $dimmed = 1;
  my $arg = shift;
  if (($arg eq "on") && ($dimmed == 1)) {
    $pigpio->write_pwm($backlight_pin, $backlight_on_level);
    print_error("backlight on");
    $dimmed = 0;
  }
  if (($arg eq "off") && ($dimmed == 0)) {
    $pigpio->write_pwm($backlight_pin, $backlight_off_level);
    print_error("backlight off");
    $dimmed = 1;
  }
}

sub dim_display_check {
  if (time() - $time_last_button_pressed > 60) {
    backlight("off");
  }
}

sub init {
  init_graphics();
  $pigpio = RPi::PIGPIO->connect('127.0.0.1');
  print_error("Unable to connect to pigpiod", "Main") if (!$pigpio->connected());
  $pigpio->set_mode($backlight_pin, RPi::PIGPIO::PI_OUTPUT);
  backlight("on");
}

sub check_for_button {
  Input::monitor_buttons();
  if ($pressed_time != $time_last_button_pressed) {
    $time_last_button_pressed = $pressed_time;
    backlight("on");
    return $pressed_key;
  }
}

sub null_sub {
}

#---------------------------------------------------------------------------------------------------
# arg1 = path to file
# return ref to json hash else null
sub get_json {
  my $url = shift;
  $url = $plexUrl . $url;
  my $browser = LWP::UserAgent->new;
  $browser->agent('Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:83.0) Gecko/20100101 Firefox/83.0');
  $browser->timeout(60);
  my $req = HTTP::Request->new("GET", $url, \@tokens);
  my $res = $browser->request($req);
  if ($res->code == 500) {
    print_error("HTTP code 500 when retrieving json, try again in 10s");
    sleep(10);
    $res = $browser->request($req);
  }
  if (($res->is_success) && ($res->code == 200)) {
    my $page = $res->decoded_content;
    #print_error("Retrieved page: $page");
    my $data = parse_json_safe($page);
    if (! defined($data)) {
      print_error("Error extracting JSON from Plex response");  
    }
    return $data;
  } else {
    print_error("Error retrieving json from Plex: " . $res->status_line);
    return;
  }
}

sub convert_tokens_to_string {
  return if length($plexParams) > 0;
  foreach my $i (0 .. (scalar(@tokens) / 2) - 1) {
    $plexParams .= "&" . $tokens[$i << 1] . "=" . $tokens[($i << 1) + 1];
  }
  #print_error("plex params = $plexParams");
}

# arg1 = path to image file
# save image to /home/pi/software/images/<arg1>
sub get_thumb {
  my $url_leaf = shift;
  my $file = "/home/pi/software/images/" . $url_leaf . ".jpg";
  $file =~ s#//#/#;
  return if -e $file;
  my ($filename, $directories, $suffix) = fileparse($file);
  mkpath($directories);
  convert_tokens_to_string();
  my $url = $plexUrl . "/photo/:/transcode?width=74&height=74&minSize=1&session=plexaudio&url=" . $url_leaf . $plexParams;
  #print_error("getting image from $url");
  my $browser = LWP::UserAgent->new;
  $browser->agent('Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:83.0) Gecko/20100101 Firefox/83.0');
  $browser->timeout(60);
  my $req = HTTP::Request->new("GET", $url, \@tokens);
  my $res = $browser->request($req);
  if ($res->code == 500) {
    print_error("HTTP code 500 when retrieving image, try again in 10s");
    sleep(10);
    $res = $browser->request($req);
  }
  if (($res->is_success) && ($res->code == 200)) {
    my $image = $res->decoded_content;
    if (length($image) < 100) {
      print_error("Error extracting image from Plex response");  
    }
    open my $fh, ">:raw", $file;
    print $fh $image;
    close $fh;
    return;
  } else {
    print_error("Error retrieving image from Plex: " . $res->status_line);
    return;
  }
}

# Check that arg1 is a ref to a hash containing a key for arg2
# return 0 if check fails, else 1
sub check_hash_for_item {
  my $ref = shift;
  my $key = shift;
  if (ref($ref) ne "HASH") {
    print_error("Expecting HASH in JSON with $key");
    return 0;
  }
  my %hash = %$ref;
  if (! $hash{$key}) {
    print_error("No $key in JSON");
    return 0;
  }
  return 1;
}

# Check that arg1 is a ref to an array
# return 0 if check fails, else 1
sub check_array {
  my $ref = shift;
  if (ref($ref) ne "ARRAY") {
    print_error("Expecting ARRAY in JSON");
    return 0;
  }
  return 1;
}

# parse playlist items
sub process_playlist_items {
  my ($page_url, $playlist_ref) = @_;
  my $ref = get_json($page_url);
  if (! defined $ref) {
    print_error("Unable to GET $page_url");
    return;
  }
  return unless check_hash_for_item($ref, "MediaContainer");
  my %hash = %$ref;
  $ref = $hash{"MediaContainer"};
  return unless check_hash_for_item($ref, "Metadata");
  return unless check_hash_for_item($ref, "title");
  %hash = %$ref;
  $ref = $hash{"Metadata"};
  #my $playlist_title = $hash{"title"};
  #utf8::decode($playlist_title);
  my @tracks = ();
  return unless check_array($ref);
  my @array = @$ref;
  foreach my $track_ref (@array) {
    next unless check_hash_for_item($track_ref, "duration");
    my %track_info;
    $track_info{"duration"} = $$track_ref{"duration"};
    $track_info{"album_title"} = $$track_ref{"parentTitle"};
    utf8::decode($track_info{"album_title"});
    $track_info{"track_title"} = $$track_ref{"title"};
    utf8::decode($track_info{"track_title"});
    $track_info{"artist_name"} = $$track_ref{"originalTitle"};
    $track_info{"artist_name"} = $$track_ref{"grandparentTitle"} unless $track_info{"artist_name"};
    #print_hash_params($track_ref) unless $track_info{"artist_name"};
    utf8::decode($track_info{"artist_name"});
    $track_info{"thumbnail"} = $$track_ref{"thumb"} . ".jpg";
    get_thumb($$track_ref{"thumb"}) if $$track_ref{"thumb"};
    next unless check_array($$track_ref{"Media"});
    next unless check_hash_for_item($$track_ref{"Media"}->[0], "Part");
    my $part = $$track_ref{"Media"}->[0]->{"Part"};
    next unless check_array($part);
    next unless check_hash_for_item($part->[0], "file");
    my $p = $part->[0]->{"file"} =~ s#/media/music/#/mnt/music/#r;
    if (-e $p) {
      $track_info{"url"} = $p;
    } else {
      print_error("oops, can't find path $p");
      next;
    }
    #print_error("Playlast track url = $track_info{'url'}");
    push(@tracks, \%track_info);
    #print_error("Added track $track_info{'track_title'} // $track_info{'artist_name'} to playlist $playlist_title");
  }
  $playlist_ref->{"tracks"} = \@tracks;
}

# parse list of playlists
sub process_playlists_top {
  my $page_url = shift;
  my $ref = get_json($page_url);
  if (! defined $ref) {
    print_error("Unable to GET $page_url");
    return;
  }
  return unless check_hash_for_item($ref, "MediaContainer");
  my %hash = %$ref;
  $ref = $hash{"MediaContainer"};
  return unless check_hash_for_item($ref, "Metadata");
  %hash = %$ref;
  $ref = $hash{"Metadata"};
  return unless check_array($ref);
  my @array = @$ref;
  foreach my $i (@array) {
    if (check_hash_for_item($i, "playlistType")) {
      if ($$i{"playlistType"} eq "audio") {                     # audio playlist
        if (check_hash_for_item($i, "title") && check_hash_for_item($i, "key")) {
          utf8::decode($$i{"title"});
          #print_error("Found playlist " . $$i{"title"});
          my %playlist;
          $playlist{"text"} = $$i{"title"};
          #$playlist{"icon"} = $$i{"composite"} . ".jpg";
          #print_error("Playlist image url = " . $playlist{"icon"});
          push(@playlist_menu_items, \%playlist);
          #get_thumb($$i{"composite"}) if $$i{"composite"};
          process_playlist_items($$i{"key"}, \%playlist);
        }
      }
    }
  }
}

sub get_playlists {
  print_error("Retrieving playlist data");
  process_playlists_top("/playlists");
  print_error("Finished retrieving playlist data");
}

#---------------------------------------------------------------------------------------------------
sub display_radio_menu {
  Play::stop();
  print_radio_menu(\%radio_menu);
  $button_subs = \%radio_menu_btns;
  $loop_sub = \&display_radio_monitor;
}

sub display_radio_monitor {
  dim_display_check();
}

sub display_radio_connecting {
  print_display_with_text(\%radio_connecting);
  $button_subs = \%radio_connecting_btns;
  $loop_sub = \&radio_connecting_monitor;
  if (Play::connect_speaker()) {
    Play::play($radio_menu_items[$radio_menu{"highlight"}]->{"url"});
  } else {
    print_error("Can't connect to speaker");
    display_radio_menu();
  }
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
  Play::stop() if Play::check_connected_to_speaker() != 1;            # stop if speaker connection drops
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
  Play::stop();
  print_playlist_menu(\%playlist_menu);
  $button_subs = \%playlist_menu_btns;
  $loop_sub = \&display_playlist_monitor;
}

sub display_playlist_monitor {
  dim_display_check();
}

sub display_playlist_connecting {
  print_display_with_text(\%playlist_connecting);
  $button_subs = \%playlist_connecting_btns;
  $loop_sub = \&playlist_connecting_monitor;
  if (Play::connect_speaker()) {
    my $track_ref = $playlist_menu_items[$playlist_menu{"highlight"}]->{"tracks"};
    if (scalar(@$track_ref) > 0) {
      $playlist_menu{"playing track no"} = int rand(scalar @$track_ref);
      Play::play($track_ref->[$playlist_menu{"playing track no"}]->{"url"});
    } else {
      display_playlist_menu();
    }
  } else {
    print_error("Can't connect to speaker");
    display_playlist_menu();
  }
}

sub playlist_connecting_monitor {
  my $state = Play::status();
  #print_error("state = $state");
  if ($state eq "Playing") {
    display_playlist_playing();
  } elsif (($state ne "Opening") && ($state ne "Buffering") && ($state ne "Paused")) {
    display_playlist_menu();
  }
}

sub update_playlist_menu {
  my $btn = shift;
  if ($btn eq "yellow") {                   # up
    return if $playlist_menu{"highlight"} == 0;
    $playlist_menu{"highlight"}--;
    print_menu_items($playlist_menu{"items"}, $playlist_menu{"highlight"});
    return;
  }
  if ($btn eq "blue") {                     # down
    return if $playlist_menu{"highlight"} == scalar(@{$playlist_menu{"items"}}) - 1;
    $playlist_menu{"highlight"}++;
    print_menu_items($playlist_menu{"items"}, $playlist_menu{"highlight"});
    return;
  }
}

sub display_playlist_playing {
  print_playlist_playing(\%playlist_playing);
  $button_subs = \%playlist_playing_btns;
  $loop_sub = \&playlist_playing_monitor;
}

sub playlist_playing_monitor {
  my $state = Play::status();
  #print_error("state = $state");
  if ($state ne "Playing") {
    playlist_playing_next();
  }
  Play::stop() if Play::check_connected_to_speaker() != 1;            # stop if speaker connection drops
}

sub playlist_playing_next {
  my $track_ref = $playlist_menu_items[$playlist_menu{"highlight"}]->{"tracks"};
  my $last_track = $playlist_menu{"playing track no"};
  if (scalar(@$track_ref) > 1) {
    while(1) {
      $playlist_menu{"playing track no"} = int rand(scalar @$track_ref);
      last if $playlist_menu{"playing track no"} != $last_track;    # only break out of loop once we have a different track number
    }
  }
  print_display_with_text(\%playlist_connecting);
  $button_subs = \%playlist_connecting_btns;
  $loop_sub = \&playlist_connecting_monitor;
  Play::play($track_ref->[$playlist_menu{"playing track no"}]->{"url"});
}

#---------------------------------------------------------------------------------------------------
sub display_initialising {
  print_display_with_text(\%initialising);
}

#---------------------------------------------------------------------------------------------------
init();
`systemctl is-system-running --wait`;                 # wait for system to finish booting
display_initialising();
Input::init();
Play::init();
get_playlists();
display_radio_menu();

my $key;
while (1) {
  $loop_sub->();
  if ($key = check_for_button()) {
    if (defined $button_subs->{$key}) {
      $button_subs->{$key}->($key);
    }
  }
  Time::HiRes::sleep(0.1);
}