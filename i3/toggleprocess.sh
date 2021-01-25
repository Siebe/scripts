#/usr/bin/env bash
INPUT=$1

if ! pgrep -x "$INPUT" > /dev/null
then
	echo "$INPUT on"
	redshift 3500:3500 2>&1 > /dev/null &
else
	echo "$INPUT off"
	pkill -x "$INPUT"
fi

