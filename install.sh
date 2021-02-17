#!/usr/bin/env bash

usage () {
  echo "Install my awesome scripts and configs, usage:"
  echo "./install.sh [-rpvd] [-f SHELLCONFIG]"
  echo "-r remove instead of install"
#  echo "-m MODULES: comma separated list of modules to install, all by default"
  echo "-f SHELLCONFIG: path to shell config file, zsh AND bash by default"
  echo "-p: attempt to install prequisites"
  echo "-v: verbose mode"
  echo "-d: dry-run"
}

while getopts ":hrm:f:pvd" options
do
	case $options in
			h ) usage; exit 0;;
   		r ) remove=1;;
#      m ) modules="${OPTARG}";;
      f ) shellconfig="${OPTARG}";;
      p ) prequisites=1;;
      v ) verbose=1;;
      d ) dry_run=1;;
      ? ) echo 'Error: invalid option'; usage; exit 1;;
	esac
done

export SCRIPT_DIR=$(dirname "$(realpath "$0")")
I3_CONFIG=$HOME/.config/i3/config
BASH_CONFIG=$HOME/.bashrc
ZSH_CONFIG=$HOME/.zshrc
PROFILE=$HOME/.profile

echo $SCRIPT_DIR

if [ -z "$remove" ]; then
  if [ -n "$prequisites" ]; then
    sudo apt install i3 i3blocks i3lock compton vim redshift scrot
    sudo snap install kubectl --classic
    if [ ! -f "$I3_CONFIG" ]; then
      mkdir -p $HOME/.config/i3
      cp $SCRIPT_DIR/lib/configs/i3config.conf I3_CONFIG
    fi
  fi
  fileline="$SCRIPT_DIR/lib/fileline.sh -f"
else
  fileline="$SCRIPT_DIR/lib/fileline.sh -rf"
fi

echo $fileline

install_shell () {
  file=$1
  echo installing shell $file
  #$fileline $file -- "
#Custom scripts stuff"
  #$fileline $file -- "alias kellogs='\$SCRIPT_DIR/k8s/klog.sh'"
}

$fileline $PROFILE -- "
#Custom scripts stuff"
$fileline $PROFILE -k -- "export SCRIPT_DIR=\"$SCRIPT_DIR\""

if [ -n "$shellconfig" ]; then
  install_shell $shellconfig
else
  [ -f "$BASH_CONFIG" ] && install_shell $BASH_CONFIG
  [ -f "$ZSH_CONFIG" ] && install_shell $ZSH_CONFIG
fi