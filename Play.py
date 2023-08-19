from UserDetails import speaker_mac, speaker_vol
from Utils import print_error, run_cmd

import vlc
import pygame
from time import sleep

# ret True if connected
def check_connected_to_speaker():
  res = run_cmd(["hciconfig", ])
  #print_error("res = " + res)
  tmp = "RUNNING \n" in res
  #print_error(str(tmp))
  return tmp
#  res = run_cmd(["bluetoothctl", "info", speaker_mac])
  #print_error("res = " + res)
#  return "Connected: yes" in res

# connect to speaker
# return True if ok
def connect_speaker():
  print_error("connecting to speaker mac = " + speaker_mac)
  if check_connected_to_speaker(): return True
  res = run_cmd(["sudo", "systemctl", "restart", "bluetooth"])                   # bluetoothd needs to be started after pulseaudio else no audio plays through speaker
  i = 0
  while (True):
    sleep(1)
    res = run_cmd(["journalctl", "--since=-1m", "-t", "bthelper", "-n 2", "-r"])
    print_error("result = " + res)
    if "Changing power on succeeded" in res: break
    print_error("waiting for bluetooth to restart")
    i += 1
    if i == 60: 
      print_error("Error restarting bluetooth")
      return False
  res = run_cmd(["bluetoothctl", "connect", speaker_mac])
  print_error("result = " + res)
  if "Connection successful" in res:
    print_error("Bluetooth connection successful")
    return True
  return False

class Player:
  volume = 0
  player = None
  playing = False

  def __init__(self):
    res = run_cmd(["bluetoothctl", "disconnect", speaker_mac])           # make sure speaker is not connected else restart of bluetoothd will not happen in connect_speaker
    pa = run_cmd(["pulseaudio", "--start"])
    self.player = vlc.MediaPlayer()
    pygame.mixer.init()
    self.set_volume(speaker_vol)

  def playing(self):
    return playing

  def play(self, url):
    global playing
    self.player.stop()
    try:
      if url.startswith("http"):
        print_error("play url = " + url)
        self.player = vlc.MediaPlayer()
        self.player.set_mrl(url)
        self.player.play()
      else:
        print_error("play media = " + url)
        pygame.mixer.music.load(url)
        pygame.mixer.music.play()
      playing = True
      self.set_volume(self.volume)
      return True
    except:
      print_error("Error trying to play " + url)
      return False

  def stop(self):
    global playing
    self.player.stop()
    pygame.mixer.music.stop()
    playing = False

  def set_volume(self, vol):
    self.volume = vol
    print_error("volume set to " + str(self.volume))
    self.player.audio_set_volume(self.volume)

  def volume_up(self):
    self.set_volume(min(100, self.volume + 5))

  def volume_down(self):
    self.set_volume(max(5, self.volume - 5))

# 'NothingSpecial',
# 'Opening',
# 'Buffering',
# 'Playing',
# 'Paused',
# 'Stopped',
# 'Ended',
# 'Error'
  def status(self):
    if pygame.mixer.music.get_busy():
      return "Playing"
    else:
      tmp = str(self.player.get_state())
      return tmp[6: ]
