package Input;

use v5.28;
use strict;

our @EXPORT = qw ( init monitor_buttons $pressed_key $pressed_time );
use base qw(Exporter);

use lib "/home/pi/software";
use Utils;
use UserDetails;

use RPi::Pin;
use RPi::Const qw(:all);
use Time::HiRes;

my $green_pin;
my $red_pin;
my $yellow_pin;
my $blue_pin;
my %button_definitions = ("green" => {"pin_no" => $GREEN_BTN, "history" => "1111"}, 
                          "red" => {"pin_no" => $RED_BTN, "history" => "1111"}, 
                          "yellow" => {"pin_no" => $YELLOW_BTN, "history" => "1111"}, 
                          "blue" => {"pin_no" => $BLUE_BTN, "history" => "1111"});

our $pressed_key;
our $pressed_time;

sub init {
  foreach my $btn (keys %button_definitions) {
    $button_definitions{$btn}->{"pin"} = RPi::Pin->new($button_definitions{$btn}->{"pin_no"});
    $button_definitions{$btn}->{"pin"}->pull(PUD_UP);
  }
}

sub monitor_buttons {
  my $str;
  foreach my $btn (keys %button_definitions) {
    $str = $button_definitions{$btn}->{"history"};
    $str = substr($str, 1, 3);
    $str .= $button_definitions{$btn}->{"pin"}->read();
    $button_definitions{$btn}->{"history"} = $str;
    #print_error("Button $btn history = $str");
    if ($str eq "1100") {
      $pressed_key = $btn;
      $pressed_time = Time::HiRes::time();
    }
  }
}


1;
