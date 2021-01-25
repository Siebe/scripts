#/usr/bin/env bash

i3-msg -q floating enable
i3-msg -q resize set 480px 120px
i3-msg -q move position 900px 630px
sudo apt update
sudo apt dist-upgrade -y
sudo apt autoremove -y
sudo apt autoclean -y
exit
