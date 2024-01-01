#!/usr/bin/env bash
REDSHIFT_OFF=$(xrandr --verbose | grep Gamma.*1.0:1.0:1.0 | wc -l)
echo $REDSHIFT_ON

if [ "0" -ne "$REDSHIFT_OFF" ]
then
	redshift -O 3500 2>&1 > /dev/null && notify-send --icon=gtk-info Redshift "Redshift on"
else
	redshift -x 2>&1 > /dev/null && notify-send --icon=gtk-info Redshift "Redshift off"
fi

