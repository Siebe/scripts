#/usr/bin/env bash
REDSHIFT_OFF=$(xrandr --verbose | grep Gamma.*1.0:1.0:1.0 | wc -l)
echo $REDSHIFT_ON

if [ "1" -eq "$REDSHIFT_OFF" ]
then
	echo "redshift on"
	redshift -O 3500 2>&1 > /dev/null 
else
	echo "redshift off"
	redshift -x 2>&1 > /dev/null
fi

