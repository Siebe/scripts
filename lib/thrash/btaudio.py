#!/usr/bin/env python

import os;
import re;
import string;

btdevices = os.environ['SCRIPT_DIR']+'/btdevices.txt';

with open(btdevices) as f:
    for line in f:
        line = line.strip();
        if (re.match(r'\w', line)):
            connected = os.popen('echo "info '+line+'" | bluetoothctl | grep Connected').read()
            print(line+' connectected: '+connected[-4:-1]);
            if connected[-4:-1] == "yes":
                disconnecting = os.popen('echo "disconnect '+line+'" | bluetoothctl | grep Attempting').read();
                print('disconnecting: '+disconnecting);
                exit();

with open(btdevices) as f:
    for line in f:
        line = line.strip();
        if (re.match(r'\w', line)):
            print(line);
            connecting = os.popen('echo "connect '+line+'" | bluetoothctl | grep Attempting').read();
            print('connecting: '+connecting);
