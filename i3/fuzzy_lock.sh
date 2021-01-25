#/usr/bin/env bash

#https://faq.i3wm.org/question/83/how-to-run-i3lock-after-computer-inactivity.1.html

# Take a screenshot
scrot /tmp/screen.png

# Pixellate it 10x
convert /tmp/screen.png -scale 10% -scale 1000% /tmp/screen_locked.png
rm /tmp/screen.png

# Lock screen displaying this image.
i3lock -i /tmp/screen_locked.png

# Turn the screen off after a delay.
sleep 60; pgrep i3lock && xset dpms force off
