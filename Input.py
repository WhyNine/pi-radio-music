from Utils import print_error, run_cmd
import UserDetails

import RPi.GPIO as GPIO
import time

button_definitions = {"green": {"pin_no": UserDetails.green_btn, "history": "1111"}, 
                      "red": {"pin_no": UserDetails.red_btn, "history": "1111"}, 
                      "yellow": {"pin_no": UserDetails.yellow_btn, "history": "1111"}, 
                      "blue": {"pin_no": UserDetails.blue_btn, "history": "1111"}}

pressed_key = ""
pressed_time = 0
dimmed = False

def init():
  global button_definitions
  GPIO.setmode(GPIO.BCM)
  #GPIO.setup(UserDetails.backlight_pin, GPIO.OUT)
  run_cmd(["gpio", "-g", "mode", "12", "pwm"])
  backlight("on")
  for btn in button_definitions:
    button_definitions[btn]["pin"] = GPIO.setup(button_definitions[btn]["pin_no"], GPIO.IN, pull_up_down=GPIO.PUD_UP)

def monitor_buttons():
  global pressed_key
  global pressed_time
  global button_definitions
  pressed_key = ""
  for btn in button_definitions:
    str = button_definitions[btn]["history"]
    str = str[1: ]
    if GPIO.input(button_definitions[btn]["pin_no"]) == 1:
      str += '1'
    else:
      str += '0'
    button_definitions[btn]["history"] = str
    #print_error("Button btn history = " + str)
    if str == "1100":
      pressed_key = btn
      pressed_time = time.clock_gettime(time.CLOCK_MONOTONIC)

def backlight(arg):
  global dimmed
  if ((arg == "on") and (dimmed == False)):
    run_cmd(["gpio", "-g", "pwm", "12", str(UserDetails.backlight_on_level * 1023 / 100)])
    print_error("backlight on")
    dimmed = True
  if ((arg == "off") and (dimmed == True)):
    run_cmd(["gpio", "-g", "pwm", "12", str(UserDetails.backlight_off_level * 1023 / 100)])
    print_error("backlight off")
    dimmed = False

