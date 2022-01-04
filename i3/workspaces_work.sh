#!/usr/bin/env bash

is_running () { #processname
  pgrep -x "${1}" > /dev/null
  return $?
}

mark_exists () { #mark
  i3-msg -t get_marks | grep -P "\b${1}\b" > /dev/null
}

class_exists () { #classname, workspace number
  i3-msg -t get_tree | \
  jq ".nodes[].nodes[].nodes[] | select(.type == \"workspace\" and .num == ${2-:1}) | .floating_nodes, .nodes, .nodes[].nodes | .[] | .window_properties.class" | \
  grep -P "\b${1}\b" > /dev/null

}
wait_for_new_window () { #classname
  i3-msg -t subscribe -m '[ "window" ]' | \
  jq -r --unbuffered "select((.change == \"new\") and (.container.window_properties.class  == \"${1}\")) | .container.id" | \
  $SCRIPT_DIR/lib/waitforit.sh -qr -- '[0-9]'
}

focus_on_class () { #classname
  i3-msg "[class=\"${1}\"] focus" > /dev/null
}

run_and_focus () { #processname, classname
    i3-msg "exec ${1}" > /dev/null
    wait_for_new_window "${2}"
    focus_on_class "${2}"
}

# Workspace 1 "Main"
i3-msg 'workspace 1' > /dev/null

if ! ( mark_exists 'MainChrome' );  then
  echo 'Starting Chrome'
  run_and_focus 'google-chrome' 'Google-chrome'
  i3-msg 'mark MainChrome' > /dev/null
fi

if ! ( class_exists 'Pavucontrol' 1 || is_running 'pavucontrol' ); then
  echo 'Starting Pavucontrol'
  run_and_focus 'pavucontrol' 'Pavucontrol'
  i3-msg 'resize set width 25 ppt' > /dev/null
  i3-msg 'split vertical' > /dev/null
fi

if ! ( class_exists 'vlc' 1 || is_running 'vlc"' ); then
  echo "Starting VLC"
  run_and_focus 'vlc' 'vlc'
  i3-msg 'resize set height 33 ppt' > /dev/null
fi

if ! ( class_exists 'nagstamon' 1 || is_running 'nagstamon' ); then
  echo "Starting Nagstamon"
  run_and_focus 'nagstamon' 'nagstamon'
fi

# Workspace 2 "Terminal"
i3-msg 'workspace 2' > /dev/null

if ! ( mark_exists 'MainTerminal' );  then
  echo 'Starting Terminal'
  run_and_focus 'gnome-terminal' 'Gnome-terminal'
  i3-msg 'mark MainTerminal' > /dev/null
fi


# Workspace 3 "Firefox"
i3-msg 'workspace 3' > /dev/null

if ! ( mark_exists 'MainFirefox' );  then
  echo 'Starting Firefox'
  run_and_focus 'firefox' 'Firefox'
  i3-msg 'mark MainFirefox' > /dev/null
fi


# Workspace 4 "PHPStorm"
i3-msg 'workspace 4' > /dev/null

if ! (class_exists 'jetbrains-phpstorm' 4 || is_running 'phpstorm'); then
  echo 'Starting PhpStorm'
  run_and_focus 'phpstorm' 'jetbrains-phpstorm'
  #wait again, cause we just focused on splash screen
  wait_for_new_window 'jetbrains-phpstorm'
  focus_on_class 'jetbrains-phpstorm'
  i3-msg 'layout Tabbed' > /dev/null
fi

#return to Terminal
i3-msg 'workspace 2' > /dev/null

#i3-msg 'workspace 1; exec google-chrome-stable; mark Main;' && sleep 1 && i3-msg '[class="Google-chrome"] focus; mark Chrome;'

#i3-msg -t get_tree | jq '.nodes[].nodes[].nodes[] | select(.type == "workspace" and .num == 1) | .floating_nodes, .nodes, .nodes[].nodes | .[] | [.name, .window_properties.class]'

#i3-msg -t subscribe -m '[ "window" ]' | jq -r --unbuffered 'select((.change == "new") and (.window_properties.class="Google-chrome")) | .container.id' | $SCRIPT_DIR/lib/waitforit.sh -vkr -- '[0-9]'
