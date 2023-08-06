import time
import subprocess
import os
import sys

def print_error(str):
  print(time.strftime("%H:%M:%S ", time.localtime()) + str, file=sys.stderr)

def check_mounted(path):
  while (is_folder_empty(path)):
    print_error("Waiting for path to become available")
    run_cmd(["sudo", "mount", "-av"])
    time.sleep(10)

def is_folder_empty(dirname):
  if not os.path.isdir(dirname): sys.exit("Folder does not exit")
  #print_error("Checking folder contents: " + str(os.listdir(dirname)))
  return len(os.listdir(dirname)) == 0

def run_cmd(args):
    return subprocess.run(args, text=True, capture_output=True).stdout
