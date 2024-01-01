#!/usr/bin/env bash
COMMAND="$1"
PROCESSNAME=${COMMAND##*/}

#echo $PROCESSNAME
#ARGS=${@:2}
#echo $ARGS
#echo $COMMAND "$ARGS"

if ! pgrep -x "$PROCESSNAME" > /dev/null
then
	$COMMAND "${@:2}" 2>&1 > /dev/null &
	sleep 0.1
	if ! pgrep -x "$PROCESSNAME" > /dev/null
	then
	  notify-send --icon=gtk-info 'Toggle Process' "$PROCESSNAME failed"
  else
	  notify-send --icon=gtk-info 'Toggle Process' "$PROCESSNAME on"
	fi
else
	pkill -x "$PROCESSNAME" && notify-send --icon=gtk-info 'Toggle Process' "$PROCESSNAME off" || \
  notify-send --icon=gtk-info 'Toggle Process' "$PROCESSNAME failed"
fi

