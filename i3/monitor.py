#!/usr/bin/env python

import os;
import sys;

connected = int(os.popen('xrandr | grep "HDMI1 connected" | wc -l').read());

if (connected == 0):
    print("HDMI1 not connected");
    exit;

modeExists = int(os.popen('xrandr | grep "1920x1080" | wc -l').read());

if (modeExists == 0):
    os.system('xrandr --newmode "1920x1080"  138.50  1920 1968 2000 2080  1080 1083 1088 1111 +hsync -vsync');
    os.system('xrandr --addmode VGA1 1920x1080');

os.system('xrandr --output HDMI1 --mode 1920x1080 --right-of LVDS1');
