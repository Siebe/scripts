#!/usr/bin/env bash

usage () {
  echo "Install my awesome scripts and configs, usage:"
  echo "./install.sh [-rpGvd] [-f SHELLCONFIG]"
  echo "-r remove instead of install"
#  echo "-m MODULES: comma separated list of modules to install, all by default"
  echo "-f SHELLCONFIG: path to shell config file, zsh AND bash by default"
  echo "-p: attempt to install prequisites"
  echo "-G: no gui (i3), shell commands only"
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
      G ) no_gui=1;;
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

if [ -z "$remove" ]; then
  if [ -n "$prequisites" ]; then
    echo "* installing APT prequisites"
    sudo apt install vim zsh
    [ -n "$no_gui"] && sudo apt install i3 i3blocks i3lock compton redshift scrot fonts-font-awesome feh xautolock
    echo "* installing Snap prequisites"
    sudo snap install kubectl --classic
    if [ -n "$no_gui"] && [ ! -f "$I3_CONFIG" ]; then
      echo "* initiating i3 config"
      mkdir -p $HOME/.config/i3
      cp $SCRIPT_DIR/lib/configs/i3config.conf I3_CONFIG
    fi
    echo "* installing oh-my-zsh from Github"
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
  fi
  fileline="$SCRIPT_DIR/lib/fileline.sh -vf"
else
  fileline="$SCRIPT_DIR/lib/fileline.sh -vrf"
fi

install_k8s_aliases () {
  file=$1
  echo "* Installing k8s aliases in shell config ${file}"
  $fileline $file -- "#### Custom K8S scripts stuff ####"
  $fileline $file -- "alias kellogs='\$SCRIPT_DIR/k8s/klog.sh'"
  $fileline $file -- "alias klog='\$SCRIPT_DIR/k8s/klog.sh'"
  $fileline $file -- "alias kdesc='\$SCRIPT_DIR/k8s/kdesc.sh'"
  $fileline $file -- "alias kget='\$SCRIPT_DIR/k8s/kget.sh'"
  $fileline $file -- "alias kwatch='\$SCRIPT_DIR/k8s/kwatch.sh'"
  $fileline $file -- "alias krestart='\$SCRIPT_DIR/k8s/krestart.sh'"
}

install_lib_aliases () {
  file=$1
  echo "* Installing other aliases in shell config ${file}"
  $fileline $file -- "#### Custom scripts stuff ####"
  $fileline $file -- "alias fileline='\$SCRIPT_DIR/lib/fileline.sh'"
  $fileline $file -- "alias limitbw='\$SCRIPT_DIR/lib/limit-bandwith.sh'"
  $fileline $file -- "alias ipcount='\$SCRIPT_DIR/lib/nginx-ip-count.sh'"
}

update_i3_config () {
  echo "* Adding stuff to i3 config ${I3_CONFIG}"
}

$fileline $PROFILE -- "#Custom scripts stuff"
$fileline $PROFILE -k -- "export SCRIPT_DIR=\"${SCRIPT_DIR}\""

if [ -n "$shellconfig" ]; then
  install_k8s_aliases $shellconfig
  $fileline $shellconfig -- "alias k='kubectl'"
  $fileline $shellconfig -- "eval \"\$(thefuck --alias)\""
  install_lib_aliases $shellconfig
else
  if [ -f "$BASH_CONFIG" ];then
    install_k8s_aliases $BASH_CONFIG
    $fileline $BASH_CONFIG -- "alias k='kubectl'"
    $fileline $BASH_CONFIG -- "source <(kubectl completion bash)"
    $fileline $BASH_CONFIG -- "source <(k completion bash | sed \"s/\bkubectl\b/k/g\")"
    $fileline $BASH_CONFIG -- "eval \"\$(thefuck --alias)\""
    install_lib_aliases $BASH_CONFIG
  fi
  if [ -f "$ZSH_CONFIG" ]; then
    install_k8s_aliases $ZSH_CONFIG
    $fileline $ZSH_CONFIG -k -- "plugins=(ansible docker dotenv git golang homestead kubectl laravel microk8s npm python ssh-agent thefuck vim-interaction)"
    install_lib_aliases $ZSH_CONFIG
  fi
fi

if [ -n "$no_gui"]; then
  update_i3_config
fi