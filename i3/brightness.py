#!/usr/bin/env python

import os;
import sys;

#For cbacklight to work you might need to:


# sudo chown root:video /sys/class/backlight/intel_backlight/brightness
# sudo chmod 664 /sys/class/backlight/intel_backlight/brightness

# or 
# https://superuser.com/questions/484678/cant-write-to-file-sys-class-backlight-acpi-video0-brightness-ubuntu

getBacklightPercentCommand = '$SCRIPT_DIR/i3/cbacklight | grep -Po "\d*\.\d+"'
setBacklightPercentCommand = '$SCRIPT_DIR/i3/cbacklight --set '

# getBacklightPercentCommand = 'xbacklight'
# setBacklightPercentCommand = 'xbacklight -set '

brightness = round(float(os.popen(getBacklightPercentCommand).read()));
print("Current brightness: "+str(brightness));

multiply = int(sys.argv[1]);
print("Multiplier input: "+str(multiply));

#overide functions
if (brightness == 1.0):
    if (multiply > 100):
        brightness = 5;
        multiply = 100;
    else:
        brightness = 0;
        multiply = 0;
elif (brightness == 0.0):
    if (multiply > 100):
        brightness = 1;
        multiply = 100;


multiply = float(multiply / 100.0);

print(str(brightness)+" * "+str(multiply));
brightness *= multiply;

print("New brightness: "+str(brightness));

os.system(setBacklightPercentCommand+str(int(brightness)));
