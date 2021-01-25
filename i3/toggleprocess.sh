#/usr/bin/env bash
COMMAND="$*"
PROCESSNAME="$1"


if ! pgrep -x "$PROCESSNAME" > /dev/null
then
	echo "$PROCESSNAME on"
	$COMMAND 2>&1 > /dev/null &
else
	echo "$PROCESSNAME off"
	pkill -x "$PROCESSNAME"
fi

