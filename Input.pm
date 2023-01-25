package Input;

use v5.28;
use strict;

our @EXPORT = qw ( init monitor_buttons $pressed_key $pressed_time );
use base qw(Exporter);

use lib "/home/pi/software";
use Utils;

use RPi::Pin;
use RPi::Const qw(:all);
use Time::HiRes;

my $GREEN_BTN = 21;
my $green_pin;
my $RED_BTN = 26;
my $red_pin;
my $YELLOW_BTN = 19;
my $yellow_pin;
my $BLUE_BTN = 20;
my $blue_pin;
my %button_definitions = ("green" => {"pin_no" => 21, "history" => "1111"}, 
                          "red" => {"pin_no" => 26, "history" => "1111"}, 
                          "yellow" => {"pin_no" => 19, "history" => "1111"}, 
                          "blue" => {"pin_no" => 20, "history" => "1111"});

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
