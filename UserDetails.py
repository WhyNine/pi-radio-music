from Utils import print_error

from yaml import load, Loader

fh = open("/home/pi/software/UserDetails.yml", "r")
settings = load(fh, Loader = Loader)
fh.close()

# This YAML file is expected to contain:
# plex-token: <token for Plex server>
# plex-url: "http://<plex server name or IP address>:32400"
# speaker:
#   mac: <mac address of bluetooth speaker>
#   default-volume: <default volume level between 0 and 100>

if not "plex-url" in settings: print_error("No Plex URL provided") 
plexUrl = settings["plex-url"]

if not "plex-token" in settings: print_error("No Plex token provided")
plexToken = settings["plex-token"]

speaker = settings["speaker"]
speaker_mac = speaker["mac"]
speaker_vol = speaker["default-volume"]

gpio = settings["pi-pins"]
green_btn = gpio["green"]
red_btn = gpio["red"]
yellow_btn = gpio["yellow"]
blue_btn = gpio["blue"]
backlight_pin = gpio["backlight"]

backlight = settings["backlight"]
backlight_on_level = backlight["on_val"]
backlight_off_level = backlight["off_val"]
