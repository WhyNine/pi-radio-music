from spidev import SpiDev
import RPi.GPIO as GPIO
import time

dc_pin = 27
reset_pin = 22
led_pin = 17
cs_pin = 8

spi = SpiDev()
GPIO.setmode(GPIO.BCM)
GPIO.setup(dc_pin, GPIO.OUT)
GPIO.setup(reset_pin, GPIO.OUT)

GPIO.output(reset_pin, 0)
time.sleep(0.2)
GPIO.output(reset_pin, 1)
time.sleep(0.2)


spi.open(0,0)
spi.max_speed_hz = 400000
spi.no_cs = False
#spi.cshigh = False
spi.threewire = False
spi.lsbfirst = False
spi.mode = 0
GPIO.output(dc_pin, 0)
spi.writebytes([0x01])        # sw reset
time.sleep(0.2)
spi.writebytes([0x11])        # sleep out
time.sleep(0.2)
msg = [0x04]

while True:
  GPIO.output(dc_pin, 0)
  spi.writebytes(msg)
  GPIO.output(dc_pin, 1)
  answer = spi.readbytes(4)
  print(answer)
  time.sleep(0.2)

spi.close()
