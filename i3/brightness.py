#!/usr/bin/env python

import os;
import sys;

brightness = round(float(os.popen('xbacklight').read()));
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

os.system('xbacklight -set '+str(brightness)); 
