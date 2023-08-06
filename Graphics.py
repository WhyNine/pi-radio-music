# display is 160 x 128 pixels

# image buffer is organised as 2 bytes (lsb first) / pixel:
# red = F800
# green = 07E0
# blue = 001F

from Utils import print_error

from st7735_tft import ST7735_TFT
import RPi.GPIO as GPIO
import time
from PIL import Image, ImageDraw, ImageFont
import os.path

def invert_colour(colour):
  colour["red"] = 255 - colour["red"]
  colour["green"] = 255 - colour["green"]
  colour["blue"] = 255 - colour["blue"]
  return colour

def convert_colour(colour):
   return "#{:02x}{:02x}{:02x}".format(colour["blue"], colour["green"], colour["red"])

def transform_image(image):
  image_bytes = list(image.getdata())
  for i, (byte1, byte2, byte3) in enumerate(image_bytes):
    image_bytes[i] = (byte3, byte2, byte1)
  image.putdata(image_bytes)

class Graphics:
  __screen_text_colour = {
    'red'   : 255,
    'green' : 255,
    'blue'  : 255
  }

  __letter_text_colour = {
    'red'   : 255,
    'green' : 255,
    'blue'  : 0
  }

  __letter_fill_colour = {
    'red'   : 255,
    'green' : 255,
    'blue'  : 0
  }

  __pale_green = {
    'red'   : 201,
    'green' : 255,
    'blue'  : 212
  }

  __green = {
    'red'   : 0,
    'green' : 190,
    'blue'  : 0
  }

  __pale_red = {
    'red'   : 255,
    'green' : 200,
    'blue'  : 200
  }

  __red = {
    'red'   : 255,
    'green' : 0,
    'blue'  : 0
  }

  __yellow = {
    'red'   : 255,
    'green' : 255,
    'blue'  : 0
  }

  __pale_yellow = {
    'red'   : 255,
    'green' : 255,
    'blue'  : 190
  }

  __black = {
    'red'   : 0,
    'green' : 0,
    'blue'  : 0
  }

  __white = {
    'red'   : 255,
    'green' : 255,
    'blue'  : 255
  }

  __img = None
  __draw = None
  __disp = None
  __font_heading = ImageFont.truetype("/home/pi/.fonts/Commissioner-Bold.ttf", 27)
  __font_label = ImageFont.truetype("/home/pi/.fonts/Commissioner-Bold.ttf", 16)
  __font_menu_item = ImageFont.truetype("/home/pi/.fonts/Commissioner-Bold.ttf", 19)
  __font_text = ImageFont.truetype("/home/pi/.fonts/Commissioner-SemiBold.ttf", 19)

  def __init__(self):
    reset_pin = 22
    GPIO.setmode(GPIO.BCM)
    GPIO.setwarnings(False)
    GPIO.setup(reset_pin, GPIO.OUT)
    GPIO.output(reset_pin, 0)
    time.sleep(0.2)
    GPIO.output(reset_pin, 1)
    time.sleep(0.2)
    self.__disp = ST7735_TFT(
        port=0,
        cs=0,
        dc=27,
        backlight=17,
        spi_speed_hz=4000000,
        width=128,
        height=160,
        rotation=270,
        invert=0
    )
    self.__img = Image.new('RGBA', (self.__disp.width, self.__disp.height), convert_colour(self.__black))
    self.__draw = ImageDraw.Draw(self.__img)
    self.__disp.display(self.__img)

  def draw_image(self, fp, x, y):
    fp = "/home/pi/software/images/" + fp
    fp = fp.replace("//", "/")
    if os.path.isfile(fp):
      tmp, ext = os.path.splitext(fp)
      if (ext == ".png") or (ext == ".jpg"):
        image = Image.open(fp)
        #print_error("Displaying image from " + fp)
        transform_image(image)
        self.__img.paste(image, (x, y))
        self.__disp.display(self.__img)
        return image.width
      else:
        print_error("unknown extension in file " + fp)
    else:
      print_error("Unable to load file " + fp)
    return 0

  def clear_screen(self):
    self.__draw.rectangle(xy=[(0, 0), (159, 127)], fill=convert_colour(self.__black))
    self.__disp.display(self.__img)

#----------------------------------------------------------------------------------------------------------------------
  def print_heading(self, heading):
    self.__draw.rectangle(xy=[(0, 0), (159, 29)], fill=convert_colour(self.__black))
    self.draw_image("pi-logo.png", 0, 0)
    self.__draw.line(xy=[(0, 30), (159, 30)], width=1, fill=convert_colour(self.__yellow))
    self.__draw.text(xy=[25, -5], text=heading, font=self.__font_heading, fill=convert_colour(self.__screen_text_colour))
    self.__disp.display(self.__img)

# arg1 = 0 for no arrows, 1 for up/down, 2 for vol up/down
  def draw_arrows(self, flag=None):
    self.__draw.rectangle(xy=[(0, 31), (19, 108)], fill=convert_colour(self.__black))
    self.__draw.line(xy=[(20, 31), (20, 108)], width=1, fill=convert_colour(self.__yellow))
    self.__draw.line(xy=[(0, 69), (20, 69)], width=1, fill=convert_colour(self.__yellow))
    if flag == 1:
      self.draw_image("up-yellow.png", 0, 31)
      self.draw_image("down-blue.png", 0, 70)
    if flag == 2:
      self.draw_image("vol-up-yellow.png", 0, 31)
      self.draw_image("vol-down-blue.png", 0, 70)
    self.__disp.display(self.__img)

  def print_labels(self, label1=None, label2=None):
    self.__draw.line(xy=[(0, 109), (159, 109)], width=1, fill=convert_colour(self.__yellow))
    self.__draw.line(xy=[(79, 109), (79, 127)], width=1, fill=convert_colour(self.__yellow))
    self.__draw.rectangle(xy=[(0, 110), (79, 127)], fill=convert_colour(self.__pale_red))
    if label1 != None:
      length = self.__draw.textlength(text=label1, font=self.__font_label)
      self.__draw.text(xy=[39 - length/2, 107], text=label1, font=self.__font_label, fill=convert_colour(self.__red))
    self.__draw.rectangle(xy=[(80, 110), (159, 127)], fill=convert_colour(self.__pale_green))
    if label2 != None:
      length = self.__draw.textlength(text=label2, font=self.__font_label)
      self.__draw.text(xy=[120 - length/2, 107], text=label2, font=self.__font_label, fill=convert_colour(self.__green))
    self.__disp.display(self.__img)

  def clear_details_area(self):
    self.__draw.rectangle(xy=[(21, 31), (159, 109)], fill=convert_colour(self.__black))
    self.__disp.display(self.__img)

# Print string in middle of details area
  def print_text(self, str):
    self.clear_details_area()
    if str != None:
      self.__draw.text(xy=[30, 50], text=str, font=self.__font_text, fill=convert_colour(self.__screen_text_colour))
      self.__disp.display(self.__img)

#----------------------------------------------------------------------------------------------------------------------
# Print playlist menu
# arg1 = ref to hash of menu
  def print_playlist_menu(self, menu):
    self.print_heading(menu["details"]["heading"])
    self.draw_arrows(menu["details"]["arrows"])
    self.print_labels(menu["details"].get("red label"), menu["details"].get("green label"))
    self.print_menu_items(menu["items"], menu["highlight"])

# Print playlist playing
# arg1 = ref to hash of details
  def print_playlist_playing(self, menu):
    self.print_heading(menu["details"]["heading"])
    self.print_labels(menu["details"].get("red label"), menu["details"].get("green label"))
    self.draw_arrows(menu["details"]["arrows"])
    self.clear_details_area()
    highlight = menu["track info"]["highlight"]
    self.draw_image(menu["track info"]["items"][highlight]["tracks"][menu["track info"]["playing track no"]]["thumbnail"], 59, 33)

# Print radio playing
# arg1 = ref to hash of details
  def print_radio_playing(self, menu):
    self.print_heading(menu["details"]["heading"])
    self.print_labels(menu["details"].get("red label"), menu["details"].get("green label"))
    self.draw_arrows(menu["details"]["arrows"])
    self.draw_image(menu["station ref"]["image"], 21, 31)

# Print radio menu
# arg1 = ref to hash of menu
  def print_radio_menu(self, menu):
    self.print_heading(menu["details"]["heading"])
    self.draw_arrows(menu["details"]["arrows"])
    self.print_labels(menu["details"].get("red label"), menu["details"].get("green label"))
    self.print_menu_items(menu["items"], menu["highlight"])

# Print menu items in details area
# arg1 = array holding hashes:
#  'text' = text to display
#  'icon' = path to icon (optional)
# arg2 = entry to highlight
  def print_menu_items(self, array, highlight):
    self.clear_details_area()
    first = 0
    #print_error("highlight = " + str(highlight))
    if (highlight > 1):
      if highlight < len(array) - 1:
        first = max(highlight - 1, 0)
      else:
        first = max(highlight - 2, 0)
    for i in range(first, first + 3):
      x = 25
      offset = (i - first) * 26
      self.__draw.rectangle(xy=[(x, offset + 32), (159, offset + 53)], fill=convert_colour(self.__black))
      if i >= len(array):
        continue
      if "icon" in array[i]:
        width = self.draw_image(array[i]["icon"], x, offset + 33)
        x += width + 1
      if "text" in array[i]:
        text_colour = self.__screen_text_colour
        if i == highlight:
          self.__draw.rectangle(xy=[(x, offset + 33), (159, offset + 52)], fill=convert_colour(self.__pale_yellow))
          text_colour = self.__black
        self.__draw.text(xy=[x, offset + 29], text=array[i]["text"], font=self.__font_menu_item, fill=convert_colour(text_colour))
    self.__disp.display(self.__img)

  def print_display_with_text(self, menu):
    self.print_heading(menu["details"]["heading"])
    self.draw_arrows()
    self.print_labels()
    self.print_text(menu["text"])
