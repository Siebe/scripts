#!/usr/bin/env bash

monitor_state=$(cat /tmp/i3script_monitorstate 2> /dev/null || echo "right-of")
main_monitor=$(xrandr --listactivemonitors | grep -P "^\s*0:" | grep -Po "[\w-]+$")
all_monitors=($(xrandr | grep ' connected ' | grep -Po "^[\w-]+"))
orientation=""

#echo "main: $main_monitor"
#echo "all_monitors: ${all_monitors[*]}"

if [ -n "${all_monitors[1]}" ]; then
  [ -n "$main_monitor" ] && orientation="--${monitor_state} ${main_monitor}"
  command="xrandr --output ${all_monitors[1]} --auto ${orientation}"
  #echo $command
  notify-send --icon=gtk-info Screens "Secondary screen orentation ${monitor_state} laptop screen"
  $command
fi

[ "$monitor_state" == "right-of" ] && inverted_state='left-of' && new_monitor_state='left-of'
[ "$monitor_state" == "left-of" ] && inverted_state='right-of' && new_monitor_state='same-as'
[ "$monitor_state" == "same-as" ] && inverted_state='same-as' && new_monitor_state='right-of'

if [ -n "${all_monitors[2]}" ]; then
  [ -n "$main_monitor" ] && orientation="--${inverted_state} ${main_monitor}"
  [ -z "$main_monitor" ] && orientation="--${monitor_state} ${all_monitors[1]}"
  xrandr --output ${all_monitors[2]} --auto ${orientation}
  notify-send --icon=gtk-info Screens "Tertiary screen orentation ${monitor_state} laptop screen"
fi

echo $new_monitor_state > /tmp/i3script_monitorstate
