package Utils;

our @EXPORT = qw ( print_error print_hash_params find_element_in_array remove_trailing_squares remove_leading_article check_mounted );
use base qw(Exporter);

use strict;

use lib "/home/pi/software";

sub print_error {
  my $str = shift;
  print STDERR localtime() . " $str\n";
}

sub print_hash_params {
  my $ref = shift;
  my $str;
  foreach my $k (keys %$ref) {
    $str .= "$k = " . $ref->{$k} . ", ";
  }
  print_error($str);
}

sub find_element_in_array {
  my ($e, $ref) = @_;
  for my $i (0 .. scalar @$ref - 1) {
    return $i if ($e eq $$ref[$i]);
  }
  return -1;
}

# remove square brackets from end of string
sub remove_trailing_squares {
  my $text = shift;
  return $text unless substr($text, length($text) - 1, 1) eq "]";
  my $lb = rindex($text, "[");
  return $text unless $lb;
  my @split = split('\[', $text);
  return $split[0];
}

sub remove_leading_article {
  my $text = shift;
  return substr($text, 4) if ($text =~ m/^The /);
  return substr($text, 2) if ($text =~ m/^A /);
  return $text;
}

sub check_mounted {
  my $path = shift;
  while (is_folder_empty($path)) {
    print_error("Waiting for $path to become available");
    my $tmp = `sudo mount -av`;
    sleep 10;
  }
}

sub is_folder_empty { 
  my $dirname = shift; 
  opendir(my $dh, $dirname) or die "Not a directory"; 
  return scalar(grep { $_ ne "." && $_ ne ".." } readdir($dh)) == 0; 
}

1;
