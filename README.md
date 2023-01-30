# pi-radio-music
Project for Raspberry Pi to play radio and Plex playlists

The set-up is a Raspberry Pi with a small DFR0928 160 x 128 pixel display from DFRobot and four coloured buttons as input (green, red, yellow and blue).

The UI allows for the user to select a radio station or a music playlist, scraped from a Plex server. The audio is played on an external Bluetooth speaker.

The buttons are used as follows:
* green = play / skip
* red = stop / switch between radio and playlist mode
* yellow = up / volume up
* blue = down / volume down

Radio stations can either be streamed from a tvheadend server or from the internet. The metadata and images for the music is scraped from a Plex server but is played directly from the storage medium. A pigpiod daemon is expected to be running on the Pi (required to enable dimming of the backlight).

The unique parameters for an installation are held in a separate YAML file.
