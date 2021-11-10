#!/usr/bin/env bash

monitor_state=$(cat /tmp/i3script_monitorstate 2> /dev/null || echo "right")
main_monitor=$(xrandr --listactivemonitors | grep -P "^\s*0:" | grep -Po "[\w-]+$")
all_monitors=($(xrandr | grep ' connected ' | grep -Po "^[\w-]+"))
orientation=""

#echo "main: $main_monitor"
#echo "all_monitors: ${all_monitors[*]}"

if [ -n "${all_monitors[1]}" ]; then
  [ -n "$main_monitor" ] && orientation="--${monitor_state}-of ${main_monitor}"
  command="xrandr --output ${all_monitors[1]} --auto ${orientation}"
#  echo $command
  $command
fi

[ "$monitor_state" == "left" ] && monitor_state='right' || monitor_state='left'
echo $monitor_state > /tmp/i3script_monitorstate

if [ -n "${all_monitors[2]}" ]; then
  [ -n "$main_monitor" ] && orientation="--${monitor_state}-of ${main_monitor}"
  [ -z "$main_monitor" ] && orientation="--${monitor_state}-of ${all_monitors[1]}"
  xrandr --output ${all_monitors[2]} --auto ${orientation}
fi
