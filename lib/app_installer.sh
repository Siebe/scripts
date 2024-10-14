#!/usr/bin/env bash

usage() {
  echo 'Install application on Ubuntu via either custom installer, aptitude or snap. Usage:'
  echo ' ./app_installer.sh [-rvd] PACKAGE_NAME'
  echo 'PACKAGE_NAME = package to add or remove, use : to force a restriction, eg: apt:vim'
  echo '-r = remove application'
  echo '-y = yes man mode'
  echo '-E = update any external sources used by installers in ./external'
  echo '-c = restrict to Custom Installers'
  echo '-A = restrict to Apt'
  echo '-S = restrict to Snap'
  echo '-N = restrict to NPM'
  echo '-C = restrict to Cargo'
  echo '-d = dry run mode'
  echo '-v = verbose mode'
  echo ''
  echo 'Custom Installers available:'
  echo '"node" - NVM, NPM and Node'
  echo '"rustup" - Cargo and Rust'
  echo '"nvchad" - Nvim and basic NvChad configuration'
  echo '"ohmyzsh" - ZSH and Oh My Zsh'
}

examples() {
  echo ""
  echo "Examples:"
  echo "Install an application:"
  echo "./app_installer.sh vim"
  echo ""
  echo "Remove an application"
  echo "./app_installer.sh -rv vim"
}

nvm_external="https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh"
ohmyzsh_external="https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh"
rustup_external="https://sh.rustup.rs/rustup-init.sh"

SCRIPT_DIR=${SCRIPT_DIR-"../$(dirname "$(realpath "$0")")"}
EXTERNAL_DIR=${EXTERNAL_DIR-"$(dirname "$(realpath "$0")")/external"}

cargo_command=""

#check if this is sourced or executed in terminal
[[ "${BASH_SOURCE[0]}" != "${0}" ]] && sourced=1

if [ -z "$sourced" ]; then
  while getopts ":hrEycASNCdv" options; do
    case $options in
    h)
      usage
      examples
      exit 0
      ;;
    r) remove=1 ;;
    y) skip_prompt=1 ;;
    E) update_external=1 ;;
    c)
      restrict=1
      restrict_custom=1
      ;;
    A)
      restrict=1
      restrict_apt=1
      ;;
    S)
      restrict=1
      restrict_snap=1
      ;;
    N)
      restrict=1
      restrict_npm=1
      ;;
    C)
      restrict=1
      restrict_cargo=1
      ;;
    v) verbose=1 ;;
    d) dry_run=1 ;;
    ?) {
      >&2 echo 'Error: invalid option'
      usage
      exit 1
    } ;;
    esac
  done

  shift $(($OPTIND - 1))
  package_input="$1"
  p_arr=(${package_input//:/ })
  if [ -n "${p_arr[1]}" ]; then 
    package_name="${p_arr[1]}"
    case ${p_arr[0]} in
    "custom")
      restrict=1
      restrict_custom=1
      ;;
    "apt")
      restrict=1
      restrict_apt=1
      ;;
    "snap")
      restrict=1
      restrict_snap=1
      ;;
    "npm")
      restrict=1
      restrict_npm=1
      ;;
    "cargo")
      restrict=1
      restrict_cargo=1
      ;;
    ?) {
      >&2 echo "Error: invalid package input: {$package_input}"
      usage
      exit 1
    } ;;
    esac
  else
    package_name="$package_input"
  fi
fi

[ -n "$verbose" ] && wget_flags="-nv"
[ -n "$remove" ] && command="remove" || command="install"

#### MISC FUNCTIONS

url_to_filename() {
  echo "$1" | sed -Ee 's/^https?:\/\///g' -e 's/\//_/g'
}

yesno_prompt() {
  question=$1
  # skip prompt when flagged or when this file is sourced
  [ -n "$skip_prompt" ] || [ -n "$sourced" ] && return 0
  read -rp "$question (y/n) " choice
  case "$choice" in
  y | Y) return 0 ;;
  n | N) return 1 ;;
  *) {
    >&2 echo 'Error: invalid option'
    return 2
  } ;;
  esac
}

#https://stackoverflow.com/questions/85880/determine-if-a-function-exists-in-bash
fn_exists() { declare -f "$1" >/dev/null; }

#### CUSTOM INSTALLERS

run_external_installer() {
  installer_url=$1
  flag=$2
  installer=$EXTERNAL_DIR/$(url_to_filename "$installer_url")
  if ! [ -f "$installer" ] || [ -n "$update_external" ]; then
    echo --- updating external installer "$installer_url"
    command wget "$wget_flags" "$installer_url" -O "$installer"
    command chmod +x "$installer"
  fi
  [ -f "$installer" ] || {
    >&2 echo "Error: unable to download installer from ${installer_url}"
    return 1
  }
  echo --- running external installer "$installer_url"
  [ -n "$verbose" ] && {
    $installer "$flag"
    return $?
  }
  $installer "$flag" >/dev/null
  return $?
}

custom_install_node() {
  if [ -z "$remove" ]; then
    echo -- installing nvm and node
    run_external_installer $nvm_external
    export NVM_DIR=${NVM_DIR:-$HOME/.nvm}
    [ -d "$NVM_DIR" ] || {
      >&2 echo "Error: cannot use NVM, ${NVM_DIR} is not a directory"
      return 1
    }
    [ -n "$verbose" ] && source "$NVM_DIR/nvm.sh"
    [ -z "$verbose" ] && source "$NVM_DIR/nvm.sh" &>/dev/null
    echo --- running nvm to install latest stable node
    [ -n "$verbose" ] && {
      nvm install --no-progress stable
      return $?
    }
    nvm install --no-progress stable &>/dev/null
    return $?
  else
    echo -- removing nvm and node
    nvm_dir=${NVM_DIR:-$HOME/.nvm}
    [ -d "$nvm_dir" ] || {
      >&2 echo "Error: cannot remove ${nvm_dir}, not a directory"
      return 1
    }
    source "$nvm_dir/nvm.sh"
    nvm unload
    yesno_prompt "!remove NVM directory ${nvm_dir}?" || return 0
    echo --- removing nvm directory
    rm -rf "$nvm_dir"
    return $?
  fi
}

custom_install_ohmyzsh() {
  if [ -z "$remove" ]; then
    echo -- installing oh-my-zsh and zsh if needed
    if ! command which zsh > /dev/null; then
      install_apt_package zsh || return $?
    fi
    CHSH="no"
    RUNZSH="no"
    export CHSH RUNZSH
    run_external_installer $ohmyzsh_external
    return $?
  else
    echo -- removing oh-my-zsh, leaving zsh
    ZSH=${ZSH:-$HOME/.oh-my-zsh}
    source "$ZSH/tools/uninstall.sh"
    return $?
  fi
}

custom_install_rustup() {
  if [ -z "$remove" ]; then
    echo -- installing rustup
    [ -n "$skip_prompt" ] || [ -z "$verbose" ] && flag="-y"
    [ -z "$verbose" ] && flag+="q"
    run_external_installer "$rustup_external" "$flag" || return $?
  fi
}

custom_install_nvchad() {
  if [ -z "$remove" ]; then
    #install neovim if it does not npm_exists
    if ! command nvim --version &>/dev/null; then
      echo -- installing nvim
      install_snap_package nvim 1 || return $?
    fi
    if [ -d "$HOME/.config/nvim" ] || [ -d "$HOME/.local/share/nvim" ]; then
      yesno_prompt "!will remove exisiting neovim configuration, ok?" || return 0
      rm -rf "$HOME/.config/nvim"
      rm -rf "$HOME/.local/share/nvim"
      rm -rf "$HOME/.cache/nvim"
    fi
    echo -- installing NvChad
    if ! command git clone https://github.com/NvChad/starter "$HOME/.config/nvim"; then
      >&2 echo Error: unable to clone https://github.com/NvChad/starter
      return 1
    fi
    command nvim --headless '+Lazy! sync' '+qa'
    return $?
  fi
}

#### APT/SNAP/NPM FUNCTIONS

install_apt_package() {
  package=$1
  if [ -z "$remove" ] && ! [ "$(find '/var/lib/apt/periodic/update-success-stamp' -mmin -60)" ]; then
    echo --- updating Apt
    [ -n "$verbose" ] && command sudo apt-get update
    [ -z "$verbose" ] && command sudo apt-get update &>/dev/null
  fi
  [ -n "$skip_prompt" ] || [ -z "$verbose" ] && flag+="-y"
  echo --- running: apt-get "$command"${flag:+ "$flag"} "$package"
  [ -n "$verbose" ] && {
    command sudo apt-get "$command"${flag:+ "$flag"} "$package"
    return $?
  }
  command sudo apt-get "$command"${flag:+ "$flag"} "$package" &>/dev/null
  return $?
}

install_snap_package() {
  package=$1
  [ -n "$2" ] && [ "$2" -eq 1 ] && [ -z "$remove" ] && classic="--classic"
  echo --- running: snap "$command" "$package"${classic:+ "$classic"}
  [ -n "$verbose" ] && {
    command sudo snap "$command" "$package"${classic:+ "$classic"}
    return $?
  }
  command sudo snap "$command" "$package"${classic:+ "$classic"} &>/dev/null
  return $?
}

install_npm_package() {
  package=$1
  [ -z "$remove" ] && npm_command="install" || npm_command="uninstall"
  echo --- running: nvm exec npm "$npm_command" -g "$package"
  [ -n "$verbose" ] && {
    nvm exec npm "$npm_command" -g "$package"
    return $?
  }
  nvm exec npm "$npm_command" -g "$package" &>/dev/null
  return $?
}

install_cargo_package() {
  package=$1
  [ -z "$remove" ] && full_command="$cargo_command install" || full_command="$cargo_command uninstall"
  echo --- running: "$full_command" "$package"
  [ -n "$verbose" ] && {
    $full_command "$package"
    return $?
  }
  $full_command "$package" &>/dev/null
  return $?
}

#### END OF FUNCTIONS

if [[ -n "$sourced" ]]; then
  #script is sourced, return here
  return 0
else
  [ -z "$package_name" ] && {
    >&2 echo "No package name given"
    usage
    exit 1
  }
fi

#### Test main installers
if [ -z "$restrict" ] || [ -n "$restrict_custom" ]; then
  [ -n "$verbose" ] && echo -- testing Custom Installers
  echo "- checking for installers: ${package_name}"
  if fn_exists "custom_install_${package_name}"; then
    echo "-- Custom Installer found"
    custom_exists=1
  fi
fi

if [ -z "$restrict" ] || [ -n "$restrict_apt" ]; then
  if [ "$(command apt-cache search --names-only "${package_name}" | grep -c "^${package_name}\s")" -eq 1 ]; then
    echo "-- Apt package found"
    apt_exists=1
  fi
fi

if [ -z "$restrict" ] || [ -n "$restrict_snap" ]; then
  [ -n "$verbose" ] && echo -- testing Snap
  if [ "$(command snap search --color=never --unicode=never "$package_name" 2>/dev/null |
    grep -c "^${package_name}\s")" -eq 1 ]; then
    if [ "$(snap info "${package_name}" | grep -P '^\s+latest/stable:' | grep -c 'classic$')" -eq 1 ]; then
      echo "-- Classic(!) Snap package found"
      snap_classic=1
    else
      echo "-- Snap package found"
    fi
    snap_exists=1
  fi
fi

#### Optional installers
if [ -n "$restrict_npm" ] || { [ -z "$restrict" ] && [ -z "$skip_prompt" ]; }; then
  export NVM_DIR=${NVM_DIR:-$HOME/.nvm}
  if [ -d "$NVM_DIR" ]; then
    [ -n "$verbose" ] && echo -- testing NVM
    source "$NVM_DIR/nvm.sh" &>/dev/null
    if [ "$(nvm exec --silent stable npm search "$package_name" --json --no-description |
      jq -r ".[]|select(.name == \"$package_name\")|.name" | wc -l)" -eq "1" ]; then
      echo -- NPM package found
      npm_exists=1
    fi
  fi
fi

cargo_command=$(command which cargo)
[ -z "$cargo_command" ] || [ "$cargo_command" == "" ] && cargo_command=$HOME/.cargo/bin/cargo

if [ -n "$restrict_cargo" ] || { [ -z "$restrict" ] && [ -z "$skip_prompt" ]; }; then
  if $cargo_command -V &>/dev/null; then
    [ -n "$verbose" ] && echo -- testing Cargo
    if [ "$($cargo_command search "$package_name" | grep -c "^${package_name}\s=")" -eq 1 ]; then
      echo -- Cargo package found
      cargo_exists=1
    fi
  fi
fi

if [ -n "$dry_run" ]; then
  [ -n "$custom_exists" ] && {
    echo "- would ${command} ${package_name} using Custom Installer"
    exit 0
  }
  [ -n "$apt_exists" ] && {
    echo "- would ${command} ${package_name} using APT"
    exit 0
  }
  [ -n "$snap_classic" ] && {
    echo "- would ${command} ${package_name} using Snap classic mode"
    exit 0
  }
  [ -n "$snap_exists" ] && {
    echo "- would ${command} ${package_name} using Snap"
    exit 0
  }
  echo "- no installer found, could not ${command} ${package_name}"
  exit 0
fi

if [ -n "$custom_exists" ] && yesno_prompt "!${command} using Custom Installer: ${package_name}?"; then
  "custom_install_${package_name}"
  ret=$?
elif [ -n "$apt_exists" ] && yesno_prompt "!${command} using Aptitude: ${package_name}?"; then
  install_apt_package "$package_name"
  ret=$?
elif [ -n "$snap_exists" ] && yesno_prompt "!${command} using Snap: ${package_name}?"; then
  install_snap_package "$package_name" "$snap_classic"
  ret=$?
elif [ -n "$npm_exists" ] && yesno_prompt "!${command} using NPM: ${package_name}?"; then
  install_npm_package "$package_name"
  ret=$?
elif [ -n "$cargo_exists" ] && yesno_prompt "!${command} using Cargo: ${package_name}?"; then
  install_cargo_package "$package_name"
  ret=$?
else
  echo "- no (other) installer found, could not ${command} ${package_name}"
  exit 1
fi

if [ "$ret" -eq 0 ]; then
  echo '- done'
  exit 0
else
  echo "Error: something went wrong, return code ${ret}"
  exit $ret
fi
