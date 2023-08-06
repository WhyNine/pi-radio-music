use v5.28;
use strict;

use Graphics::Framebuffer;
use RPi::PIGPIO ':all';
use Time::HiRes;

# dc_pin=27,reset_pin=22,led_pin=17,rotate=270
my $reset_pin = 22;
my $dc_pin = 27;
my $led_pin = 17;
my $spi;
my $pigpio;

sub print_status {
  $pigpio->write($dc_pin, 0);
  $pigpio->spi_write($spi, [0x11]);
  sleep (0.2);
  $pigpio->spi_write($spi, [0x09]);
  $pigpio->write($dc_pin, 1);
  my $data = $pigpio->spi_read($spi, 2);               # read display status
  sleep(0.2);
  print STDERR "length = " . length($data) . "\n";
  for my $i ( 1 .. length($data)) {
    print STDERR ord(substr($data, $i - 1, 1)) . "\n";
  }
}

#my $fb = Graphics::Framebuffer->new('SPLASH' => 1, 'FB_DEVICE' => "/dev/fb0");
#my $blit_data = $fb->blit_read({
#   'x'      => 0,
#   'y'      => 0,
#   'width'  => 160,
#   'height' => 128
#});
#foreach my $key (keys %$blit_data) {
#  print STDERR ("$key\n");
#}

$pigpio = RPi::PIGPIO->connect('127.0.0.1');
$pigpio->set_mode($reset_pin, RPi::PIGPIO::PI_OUTPUT);
$pigpio->set_mode($dc_pin, RPi::PIGPIO::PI_OUTPUT);
$spi = $pigpio->spi_open(0, 100000, 0b00_0000_0000_0000_0000_0000);

while (1) {
  print STDERR "hello\n";
$pigpio->write($reset_pin, 0);
sleep(0.1);
$pigpio->write($reset_pin, 1);
sleep(0.2);
print_status();
sleep(0.2);
}

#	mipi_dbi_command(dbi, MIPI_DCS_EXIT_SLEEP_MODE);#
#	msleep(500);

#	mipi_dbi_command(dbi, ST7735R_FRMCTR1, 0x01, 0x2c, 0x2d);
#	mipi_dbi_command(dbi, ST7735R_FRMCTR2, 0x01, 0x2c, 0x2d);
#	mipi_dbi_command(dbi, ST7735R_FRMCTR3, 0x01, 0x2c, 0x2d, 0x01, 0x2c,
#			 0x2d);
#	mipi_dbi_command(dbi, ST7735R_INVCTR, 0x07);
#	mipi_dbi_command(dbi, ST7735R_PWCTR1, 0xa2, 0x02, 0x84);
#	mipi_dbi_command(dbi, ST7735R_PWCTR2, 0xc5);
#	mipi_dbi_command(dbi, ST7735R_PWCTR3, 0x0a, 0x00);
#	mipi_dbi_command(dbi, ST7735R_PWCTR4, 0x8a, 0x2a);
#	mipi_dbi_command(dbi, ST7735R_PWCTR5, 0x8a, 0xee);
#	mipi_dbi_command(dbi, ST7735R_VMCTR1, 0x0e);
#	mipi_dbi_command(dbi, MIPI_DCS_EXIT_INVERT_MODE);
#	switch (dbidev->rotation) {
#	default:
#		addr_mode = ST7735R_MX | ST7735R_MY;
#		break;
#	case 90:
#		addr_mode = ST7735R_MX | ST7735R_MV;
#		break;
#	case 180:
#		addr_mode = 0;
#		break;
#	case 270:
#		addr_mode = ST7735R_MY | ST7735R_MV;
#		break;
#	}

#	if (priv->cfg->rgb)
#		addr_mode |= ST7735R_RGB;
#
#	mipi_dbi_command(dbi, MIPI_DCS_SET_ADDRESS_MODE, addr_mode);
#	mipi_dbi_command(dbi, MIPI_DCS_SET_PIXEL_FORMAT,
#			 MIPI_DCS_PIXEL_FMT_16BIT);
#	mipi_dbi_command(dbi, ST7735R_GAMCTRP1, 0x02, 0x1c, 0x07, 0x12, 0x37,
#			 0x32, 0x29, 0x2d, 0x29, 0x25, 0x2b, 0x39, 0x00, 0x01,
#			 0x03, 0x10);
#	mipi_dbi_command(dbi, ST7735R_GAMCTRN1, 0x03, 0x1d, 0x07, 0x06, 0x2e,
#			 0x2c, 0x29, 0x2d, 0x2e, 0x2e, 0x37, 0x3f, 0x00, 0x00,
#			 0x02, 0x10);
#	mipi_dbi_command(dbi, MIPI_DCS_SET_DISPLAY_ON);
#
#	msleep(100);
#
#	mipi_dbi_command(dbi, MIPI_DCS_ENTER_NORMAL_MODE);
#
#	msleep(20);




# mipi_dbi_dev_init(dbidev, &st7735r_pipe_funcs, &cfg->mode,				270);
