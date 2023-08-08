# screen is 160 x 128
# buttons:
#  green = play / select / ok / next
#  red = stop / back / cancel
#  yellow = up
#  blue = down

import Graphics
import Input
from Utils import print_error, check_mounted, run_cmd
import Play
from UserDetails import plexUrl, plexToken

from multiprocessing import Process, Queue
from time import sleep, clock_gettime, CLOCK_MONOTONIC
import requests
import os.path
import random

graphics = Graphics.Graphics()

def display_playlist_connecting_tmp(btn): display_playlist_connecting(btn)
def display_radio_menu_tmp(btn): display_radio_menu(btn)
def update_playlist_menu_tmp(btn): update_playlist_menu(btn)
def display_playlist_menu_tmp(btn): display_playlist_menu(btn)
def playlist_playing_next_tmp(btn): playlist_playing_next(btn)
def display_playlist_menu_tmp(btn): display_playlist_menu(btn)
def display_radio_connecting_tmp(btn): display_radio_connecting(btn)
def display_playlist_menu_tmp(btn): display_playlist_menu(btn)
def update_radio_menu_tmp(btn): update_radio_menu(btn)
def radio_connecting_monitor_tmp(state, connected): radio_connecting_monitor(state, connected)
def radio_playing_monitor_tmp(state, connected): radio_playing_monitor(state, connected)
def playlist_connecting_monitor_tmp(state, connected): playlist_connecting_monitor(state, connected)
def playlist_playing_monitor_tmp(state, connected): playlist_playing_monitor(state, connected)

def vol_up():
  play_queue.put(["vol_up", ])
def vol_down():
  play_queue.put(["vol_down", ])
def stop():
  play_queue.put(["stop", ])
def play(url):
  play_queue.put(["play", url])

# Possible screens (see visio):
# - radio menu
# - radio connecting
# - radio playing
# - playlist menu
# - playlist connecting
# - playlist playing

# array of dicts of:
#   text -> title of playlist
#   image -> url of thumbnail for playlist
#   tracks -> array of dicts of
#     thumbnail -> url of thumbnail for track
#     album_title -> title of album track is from
#     track_title -> title of track
#     artist_name -> name of artist
#     duration -> track length in ms
#     url -> url of media file
playlist_menu_items = []
playlist_menu_labels = {"green label" : "Play", "red label" : "Radio", "arrows" : 1, "heading" : "Playlists"}
playlist_menu = {"items" : playlist_menu_items, "details" : playlist_menu_labels, "highlight" : 0}
playlist_menu_btns = {"green" : display_playlist_connecting_tmp, "red" : display_radio_menu_tmp, "blue" : update_playlist_menu_tmp, "yellow" : update_playlist_menu_tmp}

playlist_connecting_labels = {"red label" : "Cancel", "heading" : "Playlists"}
playlist_connecting = {"text" : "Connecting ...", "details" : playlist_connecting_labels}
playlist_connecting_btns = {"red" : display_playlist_menu_tmp}

playlist_playing_labels = {"green label" : "Skip", "red label" : "Stop", "heading" : "Playing", "arrows" : 2}
playlist_playing_btns = {"green" : playlist_playing_next_tmp, "red" : display_playlist_menu_tmp, "blue" : vol_down, "yellow" : vol_up}
playlist_playing = {"details" : playlist_playing_labels, "track info" : playlist_menu}

radio_menu_items = [{"text" : "Radio 2", "icon" : "radio-2-small.png", "url" : "http://dvbadmin:dvbadmin@tvheadend:9981/stream/channelid/526472930", "image" : "BBC_Radio_2_large.png"}, 
                    {"text" : "Radio 4", "icon" : "radio-4-small.png", "url" : 'http://dvbadmin:dvbadmin@tvheadend:9981/stream/channelid/183185977', "image" : "BBC_Radio_4_large.png"}, 
                    {"text" : "Gold radio", "icon" : "gold_small.png", "url" : "https://media-ssl.musicradio.com/Gold", "image" : "gold_large.png"},
                    {"text" : "Greatest Hits", "icon" : "greatest-hits-radio-small.png", "url" : 'http://dvbadmin:dvbadmin@tvheadend:9981/stream/channel/a923c73e007d4625a5c90c4db8648a1a', "image" : "greatest-hits-radio-large.png"}]
radio_menu_labels = {"green label" : "Play", "red label" : "Playlist", "arrows" : 1, "heading" : "Radio"}
radio_menu = {"items" : radio_menu_items, "details" : radio_menu_labels, "highlight" : 0}
radio_menu_btns = {"green" : display_radio_connecting_tmp, "red" : display_playlist_menu_tmp, "blue" : update_radio_menu_tmp, "yellow" : update_radio_menu_tmp}

radio_connecting_labels = {"red label" : "Cancel", "heading" : "Radio"}
radio_connecting = {"text" : "Connecting ...", "details" : radio_connecting_labels}
radio_connecting_btns = {"red" : display_radio_menu_tmp}

radio_playing_labels = {"red label" : "Stop", "heading" : "Playing", "arrows" : 2}
radio_playing_btns = {"red" : display_radio_menu_tmp, "blue" : vol_down, "yellow" : vol_up}
radio_playing = {"details" : radio_playing_labels}             # hash "station ref" added dynamically to point at station being played

initialising_labels = {"heading" : "Initialising"}
initialising = {"text" : "Please wait ...", "details" : initialising_labels}

button_subs = None               # ref to hash of colours -> functions
loop_name = None                  # ref to function to run every main loop
loop_subs = {"radio_connecting": radio_connecting_monitor_tmp, 
             "radio_playing": radio_playing_monitor_tmp, 
             "playlist_connecting": playlist_connecting_monitor_tmp, 
             "playlist_playing": playlist_playing_monitor_tmp,
             "playlist_connecting": playlist_connecting_monitor_tmp}

tokens = {"X-Plex-Product" : "Radio and music player",
              "X-Plex-Version" : "1.0",
              "X-Plex-platform" : "RaspberryPi",
              "X-Plex-platformVersion" : "3",
              "X-Plex-device" : "radio",
              "X-Plex-model" : "radio",
              'X-Plex-Client-Identifier' : "radiomusicplayer",
              "X-Plex-Token" : plexToken,
              'Accept' : 'application/json',
              "User-Agent" : "Mozilla/5.0 (Windows NT 10.0 Win64 x64 rv:100.0) Gecko/20100101 Firefox/100.0"}
plexParams = ""

#---------------------------------------------------------------------------------------------------
def init():
  check_mounted("/mnt/music")

#---------------------------------------------------------------------------------------------------
def playlist_task(main_queue):
  menu_items = []

# arg1 = path to file
# return json else None
  def get_json(url):
    url = plexUrl + url
    res = requests.get(url, timeout=60, headers=tokens)
    if (res.status_code == 500):
      print_error("HTTP code 500 when retrieving json, try again in 10s")
      sleep(10)
      res = requests.get(url, timeout=60, headers=tokens)
    if (res.status_code == requests.codes.ok):
      try:
        return res.json()
      except:
        print_error("Error extracting JSON from Plex response")
        return 
    else:
      print_error("Error retrieving json from Plex: %d" % (res.status_code))
      return

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
      print_error("HTTP code 500 when retrieving image, try again in 10s")
      sleep(10)
      res = requests.get(url, timeout=60, headers=tokens)
    if (res.status_code == requests.codes.ok):
      image = bytearray(res.content)
      if (len(image) < 100):
        print_error("Error extracting image from Plex response");  
        fh = open(file, "wb")
        fh.write(image)
        fh.close()
      return
    else:
      print_error("Error retrieving image from Plex: " + res.reason)
      return

# Check that key exists in dictionary
# return False if check fails, else True
  def check_json_for_item(json, key):
    if (type(json) != dict):
      print_error("Expecting DICTIONARY in JSON with %s" % (key))
      return False
    if (not key in json):
      print_error("No %s in JSON" % (key))
      return False
    return True

# Check that json is a list (array)
# return False if check fails, else True
  def check_array(json):
    if (type(json) != list):
      print_error("Expecting LIST in JSON")
      return False
    return True

# parse playlist items
  def process_playlist_items(page_url, playlist):
    json = get_json(page_url)
    if (json == None):
      print_error("Unable to GET %s" % (page_url))
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
        print_error("oops, can't find path %s" % (p))
        continue
      #print("Playlast track url = %s" % (track_info['url']))
      tracks.append(track_info)
      #print_error("Added track %s // %s to playlist %s" % (track_info['track_title'], track_info['artist_name'], playlist_title))
    playlist["tracks"] = tracks

# parse list of playlists
  def process_playlists_top(page_url):
    json = get_json(page_url)
    if (json == None):
      print_error("Unable to GET " + page_url)
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
            print_error("Found playlist %s" % (i["title"]))
            playlist = {}
            playlist["text"] = i["title"]
            menu_items.append(playlist)
            process_playlist_items(i["key"], playlist)
            main_queue.put(["playlist", playlist])

  def get_playlists():
    print_error("Retrieving playlist data")
    process_playlists_top("/playlists")
    print_error("Finished retrieving playlist data")
  
  sleep(1)
  get_playlists()
  #main_queue.put(["playlist", menu_items])

#---------------------------------------------------------------------------------------------------
def display_radio_menu(btn=None):
  global button_subs
  global loop_name
  stop()
  graphics.print_radio_menu(radio_menu)
  button_subs = radio_menu_btns
  loop_name = None

def display_radio_connecting(btn):
  global button_subs
  global loop_name
  graphics.print_display_with_text(radio_connecting)
  button_subs = radio_connecting_btns
  loop_name = "radio_connecting"
  if Play.connect_speaker():
    play(radio_menu_items[radio_menu["highlight"]]["url"])
  else:
    print_error("Can't connect to speaker")
    display_radio_menu(btn)

def radio_playing_monitor(state, connected):
  #print_error("radio playing monitor, state =" + state)
  if ((state == 'Paused') or (state == 'Opening') or (state == 'Buffering')):
    print_error("state = " + state)
    display_radio_connecting()
  else:
    if ((state == 'Stopped') or (state == 'Ended') or (state == 'Error')):
      print_error("state = " + state)
      display_radio_menu()
  if not connected: stop()             # stop if speaker connection drops

def display_radio_playing(btn=None):
  global button_subs
  global loop_name
  #print_error("display radio playing")
  radio_playing["station ref"] = radio_menu_items[radio_menu["highlight"]]
  graphics.print_radio_playing(radio_playing)
  button_subs = radio_playing_btns
  loop_name = "radio_playing"

def radio_connecting_monitor(state, connected):
  #print_error("radio connecting monitor, state = " + state)
  if state == 'Playing':
    display_radio_playing()
  else:
    if ((state != "Opening") and (state != "Buffering") and (state != "Paused")):
      display_radio_menu()

def update_radio_menu(btn):
  if (btn == "yellow"):                   # up
    if radio_menu["highlight"] == 0:
      return
    radio_menu["highlight"] -= 1
    graphics.print_menu_items(radio_menu["items"], radio_menu["highlight"])
    return
  if (btn == "blue"):                     # down
    if radio_menu["highlight"] == len(radio_menu["items"]) - 1:
      return 
    radio_menu["highlight"] += 1
    graphics.print_menu_items(radio_menu["items"], radio_menu["highlight"])
    return

#---------------------------------------------------------------------------------------------------
def display_playlist_menu(btn):
  global button_subs
  global loop_name
  stop()
  graphics.print_playlist_menu(playlist_menu)
  button_subs = playlist_menu_btns
  loop_name = None

def display_playlist_connecting(btn):
  global button_subs
  global loop_name
  graphics.print_display_with_text(playlist_connecting)
  if (Play.connect_speaker()):
    track_ref = playlist_menu_items[playlist_menu["highlight"]]["tracks"]
    if len(track_ref) > 0:
      playlist_menu["playing track no"] = random.randint(0, len(track_ref))
      if play(track_ref[playlist_menu["playing track no"]]["url"]):
        button_subs = playlist_connecting_btns
        loop_name = "playlist_connecting"
      else:
        display_playlist_menu(None)
    else:
      display_playlist_menu(None)
  else:
    print_error("Can't connect to speaker")
    display_playlist_menu(None)

def playlist_connecting_monitor(state, connected):
  print_error("state = ", state)
  if (state == "Playing"):
    display_playlist_playing()
  else:
    if ((state != "Opening") and (state != "Buffering") and (state != "Paused")):
      display_playlist_menu(None)

def update_playlist_menu(btn):
  if (btn == "yellow"):                   # up
    if playlist_menu["highlight"] == 0:
      return
    playlist_menu["highlight"] -= 1
    graphics.print_menu_items(playlist_menu["items"], playlist_menu["highlight"])
    return
  if (btn == "blue"):                     # down
    if playlist_menu["highlight"] == len(playlist_menu["items"]) - 1:
      return
    playlist_menu["highlight"] += 1
    graphics.print_menu_items(playlist_menu["items"], playlist_menu["highlight"])
    return

def display_playlist_playing():
  global button_subs
  global loop_name
  graphics.print_playlist_playing(playlist_playing)
  button_subs = playlist_playing_btns
  loop_name = "playlist_playing"

def playlist_playing_monitor(state, connected):
  #print_error("state = state")
  if (state != "Playing"):
    playlist_playing_next(None)
  if not connected: stop()             # stop if speaker connection drops

def playlist_playing_next(btn):
  global button_subs
  global loop_name
  track_ref = playlist_menu_items[playlist_menu["highlight"]]["tracks"]
  last_track = playlist_menu["playing track no"]
  if len(track_ref) > 1:
    while (True):
      playlist_menu["playing track no"] = random.randint(0, len(track_ref))
      if playlist_menu["playing track no"] != last_track:    # only break out of loop once we have a different track number
        break
  graphics.print_display_with_text(playlist_connecting)
  button_subs = playlist_connecting_btns
  loop_name = "playlist_connecting"
  play(track_ref[playlist_menu["playing track no"]]["url"])

#---------------------------------------------------------------------------------------------------
def display_initialising():
  graphics.print_display_with_text(initialising)

#---------------------------------------------------------------------------------------------------
def input_task(main_queue):
  time_last_button_pressed = 0
  Input.init()
  Input.backlight("on")
  while (True):
    sleep(0.1)
    Input.monitor_buttons()
    if (Input.pressed_time != time_last_button_pressed):
      main_queue.put(["key", Input.pressed_key])
      time_last_button_pressed = Input.pressed_time
      Input.backlight("on")
    else:
      if (clock_gettime(CLOCK_MONOTONIC) - time_last_button_pressed > 60):
        Input.backlight("off")

def play_task(play_q, main_q):
  player = Play.Player()
  Play.connect_speaker()
  while True:
    try:
      message = play_q.get(True, 0.3)
      #print_error("play task: " + message[0])
      if message[0] == "play":
        player.play(message[1])
      elif message[0] == "stop":
        player.stop()
      elif message[0] == "vol_up":
        player.volume_up()
      elif message[0] == "vol_down":
        player.volume_down()
      elif message[0] == "set_vol":
        player.set_volume(message[1])
    except:
      if player.playing():
        main_q.put(["status", player.status(), Play.check_connected_to_speaker()])
      else:
        pass

#---------------------------------------------------------------------------------------------------
play_queue = Queue()
main_queue = Queue()
if __name__ == '__main__':
  init()
  run_cmd(["systemctl", "is-system-running", "--wait"])                 # wait for system to finish booting
  display_initialising()
  playlist_task = Process(target=playlist_task, args=(main_queue,)).start()
  input_task = Process(target=input_task, args=(main_queue,)).start()
  play_task = Process(target=play_task, args=(play_queue, main_queue)).start()
  display_radio_menu()

  def dummy_def (btn):
    global button_subs
    global loop_name
#    stop()
    graphics.print_display_with_text(radio_connecting)
    button_subs = radio_connecting_btns
    loop_name = "radio_connecting"
    if Play.connect_speaker():
      play(radio_menu_items[radio_menu["highlight"]]["url"])
    else:
      print_error("Can't connect to speaker")
      display_radio_menu(btn)

#  i = 0
  while (True):
#    i += 1
#    if i == 120:
#      dummy_def("green")
#      stop()
#      play(radio_menu_items[0]["url"])
#      i = 0
    try:
      message = main_queue.get(True, 0.1)
      #print_error(str(message))
      if message[0] == "key":
        button_subs[message[1]](message[1])
      elif message[0] == "status":
        #print_error("status = " + message[1])
        #print_error(loop_name)
        if loop_name != None:
          loop_subs[loop_name](message[1], message[2])
      elif message[0] == "playlist":
        playlist_menu_items.append(message[1])
      else:
        print_error("got rogue message: " + str(message[0]))
    except:
      pass
