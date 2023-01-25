package Graphics;

# display is 160 x 128 pixels

# image buffer is organised as 2 bytes (lsb first) / pixel:
# red = F800
# green = 07E0
# blue = 001F

# say 18 pixels at bottom for button labels
# title at top = 30
# 4 lines of text at 20 each
# 20 pixels at side for arrows

use v5.28;
use strict;

our @EXPORT = qw ( init_graphics clear_screen print_heading draw_arrows print_labels print_radio_menu print_menu_items print_playlist_menu print_radio_connecting print_radio_playing );
use base qw(Exporter);

use lib "/home/pi/software";

use Utils;

use Graphics::Framebuffer;
use Image::PNG;
use File::Basename;
use Image::JPEG::Size;
use List::Util;

my $fb;

my $screen_text_colour = {
   'red'   => 255,
   'green' => 255,
   'blue'  => 255,
   'alpha' => 255
};

my $letter_text_colour = {
   'red'   => 255,
   'green' => 255,
   'blue'  => 0,
   'alpha' => 255
};

my $letter_fill_colour = {
   'red'   => 255,
   'green' => 255,
   'blue'  => 0,
   'alpha' => 255
};

my $pale_green = {
   'red'   => 201,
   'green' => 255,
   'blue'  => 212,
   'alpha' => 255
};

my $green = {
   'red'   => 0,
   'green' => 190,
   'blue'  => 0,
   'alpha' => 255
};

my $pale_red = {
   'red'   => 255,
   'green' => 200,
   'blue'  => 200,
   'alpha' => 255
};

my $red = {
   'red'   => 255,
   'green' => 0,
   'blue'  => 0,
   'alpha' => 255
};

my $yellow = {
   'red'   => 255,
   'green' => 255,
   'blue'  => 0,
   'alpha' => 255
};

my $black = {
   'red'   => 0,
   'green' => 0,
   'blue'  => 0,
   'alpha' => 255
};

my $white = {
   'red'   => 255,
   'green' => 255,
   'blue'  => 255,
   'alpha' => 255
};

sub convert_colour_to_hex {
   my $colour = shift;
   return sprintf("%02x%02x%02x%02x", $$colour{"red"}, $$colour{"green"}, $$colour{"blue"}, $$colour{"alpha"});
}

sub clear_screen {
  $fb->set_color($black);
  $fb->rbox({
    'x'          => 0,
    'y'          => 0,
    'width'      => 160,
    'height'     => 128,
    'radius'     => 0,
    'pixel_size' => 1,
    'filled'     => 1
  });
}

sub init_graphics {
  $fb = Graphics::Framebuffer->new('SPLASH' => 0, 'FB_DEVICE' => "/dev/fb0");
  my ($width,$height) = $fb->screen_dimensions();
  if (($width != 160) || ($height != 128)) {
    print_error("ERROR /dev/fb0 screen width/height: $width $height, trying fb1", "Display");
    $fb = Graphics::Framebuffer->new('SPLASH' => 0, 'FB_DEVICE' => "/dev/fb1");
    my ($width,$height) = $fb->screen_dimensions();
    if (($width != 160) || ($height != 128)) {
      print_error("ERROR /dev/fb1 screen width/height: $width $height", "Display");
    } else {
      print_error("Attached to /dev/fb1", "Display");
    }
  }
  $fb->graphics_mode();
  clear_screen();
}

#----------------------------------------------------------------------------------------------------------------------
sub draw_image {
  my ($filename, $x_offset, $y_offset) = @_;
  $filename = "/home/pi/software/images/$filename";
  if (-e $filename) {
    my ($path, $root, $suffix) = fileparse($filename, ("png", "PNG", "jpg", "JPG"));
    if (lc($suffix) eq "png") {
      return draw_png($filename, $x_offset, $y_offset);
    }
    if (lc($suffix) eq "jpg") {
      return draw_jpg($filename, $x_offset, $y_offset);
    }
    print_error("Unable to draw $filename $suffix");
  } else {
    print_error("Unable to load file $filename");
  }
}

# Draw JPG at x/y position
sub draw_jpg {
  my ($filename, $x_offset, $y_offset) = @_;
  my $jpeg_sizer = Image::JPEG::Size->new;
  my ($width, $height) = $jpeg_sizer->file_dimensions($filename);
  my $icon_image = $fb->load_image({
      'x'          => $x_offset,
      'y'          => $y_offset,
      'scale_type' => 'min',
      'width'      => $width,
      'height'     => $height,
      'file'       => $filename
  });
  $fb->blit_write($icon_image);
  return $width;
}

# Draw PNG at x/y position, using alpha channel if provided
sub draw_png {
  my ($filename, $x_offset, $y_offset) = @_;
  my $png = Image::PNG->new();
  $png->read($filename);
  my $height = $png->height();
  my $width = $png->width();
  my $bit_depth = $png->bit_depth();
  if (($png->color_type() ne "RGB_ALPHA") || ($bit_depth != 8)) {          # if no alpha or if bit depth != 8, draw with no alpha
    my $icon_image = $fb->load_image({
        'x'          => $x_offset,
        'y'          => $y_offset,
        'scale_type' => 'min',
        'width'      => $width,
        'height'     => $height,
        'file'       => $filename
    });
    $fb->blit_write($icon_image);
  } else {
    #print_error("height = $height, width = $width, bit depth = $bit_depth");
    my $rows = $png->rows();
    $fb->draw_mode(ALPHA_MODE);
    foreach my $i (0 .. $height-1) {
      my $row = $$rows[$i];
      foreach my $j (0 .. $width-1) {
        my @colours = (ord(substr($row, ($j << 2) + 0, 1)), ord(substr($row, ($j << 2) + 1, 1)), ord(substr($row, ($j << 2) + 2, 1)), ord(substr($row, ($j << 2) + 3, 1)));
        #print_error("row = $i, pixel = $j, rgba = @colours");
        $fb->set_color({
          'red'   => $colours[0],
          'green' => $colours[1],
          'blue'  => $colours[2],
          'alpha' => $colours[3]
        });
        $fb->plot({
          'x' => $j + $x_offset,
          'y' => $i + $y_offset,
          'pixel_size' => 1
        });
      }
    }
  }
  $fb->draw_mode(NORMAL_MODE);
  return $width;
}

sub print_heading {
  my ($heading) = @_;
  #print_error("heading = $heading");
  draw_image("pi-logo.png", 0, 0);
  $fb->set_color($yellow);
  $fb->line({
   'x'           => 0,
   'y'           => 30,
   'xx'          => 160,
   'yy'          => 30,
   'pixel_size'  => 1,
   'antialiased' => TRUE
  });
  $fb->set_color($black);
  $fb->box({
    'x'          => 25,
    'y'          => 0,
    'xx'         => 160,
    'yy'         => 29,
    'radius'     => 0,
    'pixel_size' => 1,
    'filled'     => 1
  });
  $fb->ttf_print($fb->ttf_print({
    'x'            => 25,
    'y'            => 37,
    'height'       => 27,
    'wscale'       => 1,
    'font_path'    => '/home/pi/.fonts',
    'face'         => 'Commissioner-Bold.ttf',
    'color'        => convert_colour_to_hex($screen_text_colour),
    'text'         => $heading,
    'bounding_box' => TRUE,
    'center'       => CENTER_NONE
  }));
}

sub draw_arrows {
  my $flag = shift;
  $fb->set_color($black);
  $fb->box({
    'x'          => 0,
    'y'          => 31,
    'xx'         => 19,
    'yy'         => 108,
    'filled'     => 1
  });
  return unless $flag;
  $fb->set_color($yellow);
  $fb->line({
   'x'           => 20,
   'y'           => 31,
   'xx'          => 20,
   'yy'          => 108,
   'pixel_size'  => 1,
   'antialiased' => TRUE
  });
  $fb->line({
   'x'           => 0,
   'y'           => 69,
   'xx'          => 20,
   'yy'          => 69,
   'pixel_size'  => 1,
   'antialiased' => TRUE
  });
  draw_image("up-yellow.png", 0, 31);
  draw_image("down-blue.png", 0, 70);
}

sub print_labels {
  my ($label1, $label2) = @_;
  $fb->set_color($yellow);
  $fb->line({
   'x'           => 0,
   'y'           => 109,
   'xx'          => 160,
   'yy'          => 109,
   'pixel_size'  => 1,
   'antialiased' => TRUE
  });
  $fb->line({
   'x'           => 79,
   'y'           => 109,
   'xx'          => 79,
   'yy'          => 127,
   'pixel_size'  => 1,
   'antialiased' => TRUE
  });
  $fb->set_color($pale_red);
  $fb->box({
    'x'          => 0,
    'y'          => 110,
    'xx'         => 79,
    'yy'         => 127,
    'radius'     => 0,
    'pixel_size' => 1,
    'filled'     => 1
  });
  $fb->clip_set({
    'x'  => 0,
    'y'  => 110,
    'xx' => 78,
    'yy' => 127
  });
  $fb->ttf_print($fb->ttf_print({
    'x'            => 2,
    'y'            => 132,
    'height'       => 16,
    'wscale'       => 1,
    'font_path'    => '/home/pi/.fonts',
    'face'         => 'Commissioner-Bold.ttf',
    'color'        => convert_colour_to_hex($red),
    'text'         => $label1,
    'bounding_box' => TRUE,
    'center'       => CENTER_X
  }));
  $fb->clip_reset();
  $fb->set_color($pale_green);
  $fb->box({
    'x'          => 80,
    'y'          => 110,
    'xx'         => 159,
    'yy'         => 127,
    'radius'     => 0,
    'pixel_size' => 1,
    'filled'     => 1
  });
  $fb->clip_set({
    'x'  => 80,
    'y'  => 110,
    'xx' => 159,
    'yy' => 127
  });
  $fb->ttf_print($fb->ttf_print({
    'x'            => 82,
    'y'            => 132,
    'height'       => 16,
    'wscale'       => 1,
    'font_path'    => '/home/pi/.fonts',
    'face'         => 'Commissioner-Bold.ttf',
    'color'        => convert_colour_to_hex($green),
    'text'         => $label2,
    'bounding_box' => TRUE,
    'center'       => CENTER_X
  }));
  $fb->clip_reset();
}

sub clear_details_area {
  $fb->set_color($black);
  $fb->box({
    'x'          => 21,
    'y'          => 31,
    'xx'         => 159,
    'yy'         => 108,
    'filled'     => 1
  });
}

# Print string in middle of details area
sub print_text {
  my $str = shift;
  clear_details_area();
  return if $str eq "";
  $fb->ttf_print($fb->ttf_print({
    'x'            => 30,
    'y'            => 85,
    'height'       => 19,
    'wscale'       => 1,
    'font_path'    => '/home/pi/.fonts',
    'face'         => 'Commissioner-SemiBold.ttf',
    'color'        => convert_colour_to_hex($screen_text_colour),
    'text'         => $str,
    'bounding_box' => TRUE,
    'center'       => CENTER_NONE
  }));
}

#----------------------------------------------------------------------------------------------------------------------
# Print playlist menu
sub print_playlist_menu {

}

# Print radio connecting
# arg1 = ref to hash of menu
sub print_radio_connecting {
  my $menu_ref = shift;
  print_heading($menu_ref->{"details"}->{"heading"});
  print_labels($menu_ref->{"details"}->{"red label"}, $menu_ref->{"details"}->{"green label"});
  draw_arrows();
  print_text($menu_ref->{"text"});
}

# Print radio playing
# arg1 = ref to hash of details
sub print_radio_playing {
  my $menu_ref = shift;
  print_heading($menu_ref->{"details"}->{"heading"});
  print_labels($menu_ref->{"details"}->{"red label"}, $menu_ref->{"details"}->{"green label"});
  draw_arrows();
  draw_image($menu_ref->{"station ref"}->{"image"}, 21, 31);
}

# Print radio menu
# arg1 = ref to hash of menu
sub print_radio_menu {
  my $menu_ref = shift;
  print_heading($menu_ref->{"details"}->{"heading"});
  draw_arrows($menu_ref->{"details"}->{"arrows"});
  print_labels($menu_ref->{"details"}->{"red label"}, $menu_ref->{"details"}->{"green label"});
  print_menu_items($menu_ref->{"items"}, $menu_ref->{"highlight"});
}

# Print menu items in details area
# arg1 = ref to array holding ref's to hash:
#  'text' = text to display
#  'icon' = path to icon (optional)
# arg2 = entry to highlight
sub print_menu_items {
  my ($array_ref, $highlight) = @_;
  clear_details_area();
  my $first = 0;
  my $max = scalar(@$array_ref) - 1;
  if ($highlight > 1) {
    $first = ($highlight < $max) ? List::Util::max($highlight - 1, 0) : List::Util::max($highlight - 2, 0);
  }
  foreach my $i ($first .. $first + 2) {
    my $x = 25;
    my $offset = ($i - $first) * 26;
    $fb->set_color($black);
    $fb->box({
      'x'          => $x,
      'y'          => $offset + 32,
      'xx'         => 159,
      'yy'         => $offset + 53,
      'filled'     => 1
    });
    next if $i >= scalar(@$array_ref);
    if (exists $$array_ref[$i]->{"icon"}) {
      my $width = draw_image($$array_ref[$i]->{"icon"}, 25, $offset + 33);
      $x += $width + 1;
    }
    $fb->ttf_print($fb->ttf_print({
      'x'            => $x,
      'y'            => $offset + 59,
      'height'       => 19,
      'wscale'       => 1,
      'font_path'    => '/home/pi/.fonts',
      'face'         => 'Commissioner-Bold.ttf',
      'color'        => convert_colour_to_hex($screen_text_colour),
      'text'         => $$array_ref[$i]->{"text"},
      'bounding_box' => TRUE,
      'center'       => CENTER_NONE
    })) if exists $$array_ref[$i]->{"text"};
    if ($i == $highlight) {
      $fb->draw_mode(XOR_MODE);
      $fb->set_color($screen_text_colour);
      $fb->box({
        'x'          => $x,
        'y'          => $offset + 32,
        'xx'         => 159,
        'yy'         => $offset + 53,
        'filled'     => 1
      });
      $fb->draw_mode(NORMAL_MODE);
    }
  }
}

1;
