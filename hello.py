from PIL import Image, ImageDraw, ImageFont
import time
import numpy as np
import RPi.GPIO as GPIO
import vlc
import requests
import os.path
import threading

from st7735_tft import ST7735_TFT

# appears that the 24 bits are in reverse order
screen_text_colour = '#000000'
letter_text_colour = '#00ffff'
letter_fill_colour = '#0000ff'
pale_green = '#2bff93'    #d4ffc9
green = '#ff41ff'
pale_red = '#1313ff'      #c8c8ff
red = '#0000ff'
yellow = '#00ffff'
black = '#000000'
white = '#ffffff'

def reset_7735():
  reset_pin = 22
  GPIO.setmode(GPIO.BCM)
  GPIO.setwarnings(False)
  GPIO.setup(reset_pin, GPIO.OUT)
  GPIO.output(reset_pin, 0)
  time.sleep(0.2)
  GPIO.output(reset_pin, 1)
  time.sleep(0.2)

def init_display():
  reset_7735()
  global disp
  global img
  global draw
  disp = ST7735_TFT(
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
  img = Image.new('RGBA', (disp.width, disp.height), black)
  draw = ImageDraw.Draw(img)
  disp.display(img)

def transform_image(image):
  image_bytes = list(image.getdata())
  for i in range(len(image_bytes)):
    (byte1, byte2, byte3) = image_bytes[i]
    image_bytes[i] = (int('{:06b}'.format(byte3)[::-1], 2), int('{:06b}'.format(byte2)[::-1], 2), int('{:06b}'.format(byte1)[::-1], 2))
  image.putdata(image_bytes)

def draw_image(fp, x, y):
  image = Image.open(fp)
  transform_image(image)
  img.paste(image, (x, y))
  disp.display(img)

init_display()
font_default = ImageFont.load_default()
font_bold_30 = ImageFont.truetype("/home/pi/.fonts/Commissioner-Bold.ttf", 30)
font_thin_20 = ImageFont.truetype("/home/pi/.fonts/Commissioner-Thin.ttf", 20)
draw.text((5, 5), "Hello World!", font=font_thin_20, fill=pale_red)
draw.text((5, 30), "Bold text", font=font_bold_30, fill=pale_green)
disp.display(img)

draw_image("/home/pi/software/images/pi-logo.png", 50, 50)

def play(fp):
  global player
  player = vlc.MediaPlayer()
  player.stop()
  player.set_mrl(fp)
  player.play()

# returns State.Playing etc
def status():
  return player.get_state()


# should get this from UserDetails:
plexUrl = "http://docker:32400"
tokens = {"X-Plex-Product" : "Radio and music player",
          "X-Plex-Version" : "2.0",
          "X-Plex-platform" : "RaspberryPi",
          "X-Plex-platformVersion" : "0",
          "X-Plex-device" : "radio",
          "X-Plex-model" : "radio",
          'X-Plex-Client-Identifier' : "radiomusicplayer",
          "X-Plex-Token" : "2TE6Ln6XsJceDyVnzucp",
          'Accept' : 'application/json',
          "User-Agent" : "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:100.0) Gecko/20100101 Firefox/100.0"}

playlist_menu_items = []

# arg1 = path to file
# return ref to json hash else null ????
def get_json(url):
  url = plexUrl + url
  res = requests.get(url, timeout=60, headers=tokens)
  if (res.status_code == 500):
    print("HTTP code 500 when retrieving json, try again in 10s")
    time.sleep(10)
    res = requests.get(url, timeout=60, headers=tokens)
  if (res.status_code == requests.codes.ok):
    try:
      return res.json()
    except:
      print("Error extracting JSON from Plex response")
      return 
  else:
    print("Error retrieving json from Plex: %d" % (res.status_code))
    return

# Check that key exists in dictionary
# return False if check fails, else True
def check_json_for_item(json, key):
  if (type(json) != dict):
    print("Expecting DICTIONARY in JSON with %s" % (key))
    return False
  if (not key in json):
    print("No %s in JSON" % (key))
    return False
  return True

# Check that json is a list (array)
# return False if check fails, else True
def check_array(json):
  if (type(json) != list):
    print("Expecting LIST in JSON")
    return False
  return True

def convert_tokens_to_string():
  if 'plexParams' in globals(): return
  global plexParams
  tmp = ""
  for key in tokens:
    tmp += "&" + key + "=" + tokens[key]
  plexParams = tmp
  #print("plex params = " + plexParams)

# arg1 = path to image file
# save image to /home/pi/software/images/<arg1>
def get_thumb(url_leaf):
  file = "/home/pi/software/images/" + url_leaf + ".jpg"
  file = file.replace("//", "/")
  if os.path.isfile(file): return
  directories = os.path.dirname(file)
  if not os.path.isdir(directories): 
    os.makedirs(directories)
  convert_tokens_to_string()
  url = plexUrl + "/photo/:/transcode?width=74&height=74&minSize=1&session=plexaudio&url=" + url_leaf + plexParams
  #print("getting image from %s" % (url))
  res = requests.get(url, timeout=60, headers=tokens)
  if (res.status_code == 500):
    print("HTTP code 500 when retrieving image, try again in 10s")
    time.sleep(10)
    res = requests.get(url, timeout=60, headers=tokens)
  if (res.status_code == requests.codes.ok):
    image = bytearray(res.content)
    if (len(image) < 100):
      print("Error extracting image from Plex response");  
      fh = open(file, "wb")
      fh.write(image)
      fh.close()
    return
  else:
    print("Error retrieving image from Plex: " + res.reason)
    return

# parse playlist items
def process_playlist_items(page_url, playlist):
  json = get_json(page_url)
  if (json == None):
    print("Unable to GET %s" % (page_url))
    return
  if not check_json_for_item(json, "MediaContainer"): return
  json = json["MediaContainer"]
  if not check_json_for_item(json, "Metadata"): return
  if not check_json_for_item(json, "title"): return
  playlist_title = json["title"]
  json = json["Metadata"]
  tracks = []
  if not check_array(json): return
  for track_ref in json:
    if not check_json_for_item(track_ref, "duration"): continue
    track_info = {}
    track_info["duration"] = track_ref["duration"]
    track_info["album_title"] = track_ref["parentTitle"] if "parentTitle" in track_ref else ""
    track_info["album_title"].encode('utf-8')
    track_info["track_title"] = track_ref["title"] if "title" in track_ref else ""
    track_info["track_title"].encode('utf-8')
    track_info["artist_name"] = ""
    track_info["artist_name"] = track_ref["originalTitle"] if "originalTitle" in track_ref else track_ref["grandparentTitle"]
    #print_hash_params($track_ref) unless $track_info{"artist_name"};
    track_info["artist_name"].encode('utf-8')
    if "thumb" in track_ref:
      track_info["thumbnail"] = track_ref["thumb"] + ".jpg"
      get_thumb(track_ref["thumb"])
    if not check_array(track_ref["Media"]): continue
    if not check_json_for_item(track_ref["Media"][0], "Part"): continue
    part = track_ref["Media"][0]["Part"]
    if not check_array(part): continue
    if not check_json_for_item(part[0], "file"): continue
    p = part[0]["file"].replace("/media/music/", "/mnt/music/")
    if os.path.isfile(p):
      track_info["url"] = p
    else:
      print("oops, can't find path %s" % (p))
      continue
    #print("Playlast track url = %s" % (track_info['url']))
    tracks.append(track_info)
    #print("Added track %s // %s to playlist %s" % (track_info['track_title'], track_info['artist_name'], playlist_title))
  playlist["tracks"] = tracks

# parse list of playlists
def process_playlists_top(page_url):
  json = get_json(page_url)
  if (json == None):
    print("Unable to GET " + page_url)
    return
  if not check_json_for_item(json, "MediaContainer"): return
  json = json["MediaContainer"]
  if not check_json_for_item(json, "Metadata"): return
  json = json["Metadata"]
  if not check_array(json): return
  for i in json:
    if (check_json_for_item(i, "playlistType")):
      if (i["playlistType"] == "audio"):                     # audio playlist
        if (check_json_for_item(i, "title") and check_json_for_item(i, "key")):
          i["title"].encode('utf-8')
          print("Found playlist %s" % (i["title"]))
          playlist = {}
          playlist["text"] = i["title"]
          #$playlist{"icon"} = $$i{"composite"} . ".jpg";
          #print_error("Playlist image url = " . $playlist{"icon"});
          playlist_menu_items.append(playlist)
          process_playlist_items(i["key"], playlist)

def get_playlists():
  print("Retrieving playlist data")
  process_playlists_top("/playlists")
  print("Finished retrieving playlist data")

#get_playlists()
