#!/usr/bin/env bash

usage () {
  echo "Install my awesome scripts and configs, usage:"
  echo "./install.sh [-rpGdvv] [-f SHELLCONFIG]"
  echo "-r remove instead of install"
  echo "-f SHELLCONFIG: path to shell config file, zsh AND bash by default"
  echo "-p: attempt to install prequisites"
  echo "-G: no gui (i3)"
  echo "-K: no Kubernetes packages/aliases (k8s)"
  echo "-e: extra packages (gui only)"
  echo "-w: work packages/aliases (Pluxbox)"
  echo "-B: no backups"
  echo "-d: dry-run"
  echo "-v: verbose mode"
  echo "-vv: deep verbose mode"
}

verbose=0

main_packages="curl cowsay gcc make ntp python3 vim zsh" 
gui_packages="i3 i3blocks i3lock compton redshift scrot fonts-font-awesome feh xautolock xdotool imagemagick"
extra_packages="blueman docker.io ffmpeg gzip imagemagick jq mixxx mpv nmap pavucontrol rsync sox thefuck traceroute unrar wine winetricks whois xclip"
extra_snap_packages="brave cups pinta"
extra_snap_packages_classic="nvim rustup vlc"
work_packages="ansible google-chrome-stable docker.io git-secret jq nagstamon nmap rsync traceroute whois wireguard"
work_snap_packages="doctl firefox insomnia postman"
work_snap_packages_classic="helm phpstorm"

while getopts ":hrm:f:pGKewBvd" options
do
	case $options in
    h ) usage; exit 0;; #help duh
    r ) remove=1;; # Removal instead of installation, no prequisites
    f ) shellconfig="${OPTARG}";; # Use a alternative shell config file eg. $HOME/.csh
    p ) prequisites=1;; # Install stuff i like with apt/snap or just curl
    G ) no_i3=1;;
    K ) no_k8s=1;;
    e ) install_extra=1;;
    w ) install_work=1;;
    B ) no_backups=1;;
    v ) [ "$verbose" -eq 1 ] && verbose=2 || verbose=1;;
    d ) dry_run=1;;
    ? ) echo 'Error: invalid option'; usage; exit 1;;
	esac
done


### Globals
export SCRIPT_DIR=$(dirname "$(realpath "$0")")
I3_CONFIG=$HOME/.config/i3/config
BASH_CONFIG=$HOME/.bashrc
ZSH_CONFIG=$HOME/.zshrc
OH_MY_ZSH_CONFIG=$HOME/.oh-my-zsh
PROFILE=$HOME/.profile


### Pre-flight-checks
[ -n "$verbose" ] && echo "Running preflight checks"
if [ ! -f "$PROFILE" ]; then
  #guess we *could* fallback to /.login i dunno
  echo "Warning: PROFILE file not found: ${HOME}/.profile, trying ${HOME}/.login"
  PROFILE=$HOME/.login
  [ ! -f "$PROFILE" ] && { >&2 echo "Error: PROFILE file not found: ${PROFILE}"; usage; exit 1; }
fi
if [ ! -f "$BASH_CONFIG" ] && [ ! -f "$ZSH_CONFIG" ] && [ ! - f "$shellconfig" ]; then
    >&2 echo "Error: Not a single shell config file found, no zsh, no bash, no nothin'"; usage; exit 1;
fi
if [ -z "$no_i3" ] && [ -z "$prequisites" ] && [ ! -f "$I3_CONFIG" ]; then
    >&2 echo "Error: Can not add i3 stuffs without i3 config: ${I3_CONFIG}"; usage; exit 1;
fi
if [ -n "$prequisites" ]; then
  ( type apt &>/dev/null ) || { >&2 echo "Error: want to install prequisites, but apt not found!"; usage; exit 1; }
  ( type snap &>/dev/null ) || echo "Warning: want to install prequisites, but snap not found!";
fi
if [ -n "$shellconfig" ] && [ ! -f "$shellconfig" ]; then
  echo "Warning: can not find shell config file ${shellconfig}, so not doing that one today."
  $shellconfig="";
fi
[ -n "$verbose" ] && echo "Finished preflight checks"


### Prepare the flags for the beautiful $removeEmptyLines command:
[ -n "$verbose" ] && echo "Preparing fileline command"
if [ -z "$remove" ]; then
  fileLine="$SCRIPT_DIR/lib/fileline.sh -"
else
  fileLine="$SCRIPT_DIR/lib/fileline.sh -r"
fi
[ -n "$dry_run" ] && fileLine="${fileLine}d"
[ -n "$verbose" ] && [ "$verbose" -gt 1 ] && fileLine="${fileLine}v"
fileLine="${fileLine}f"


### get the $WAN_IP and prepare empty lines command
[ -n "$verbose" ] && echo "Preparing whatsmyip and remove-emptyline command"
source $SCRIPT_DIR/lib/whatsmyip.sh &>/dev/null
# I really like empty lines in config files for clarity, so in order to add them:
# always append empty lines to the files and remove them from the bottom afterwards if nothing else gets appended.
# it's a shite workaround for my inability to perform a simple multiline search including empty lines
removeEmptyLines="$SCRIPT_DIR/lib/remove-empty-lines.sh -B"
[ -n "$dry_run" ] && removeEmptyLines="${removeEmptyLines}d"
[ -n "$verbose" ] && [ "$verbose" -gt 1 ] && removeEmptyLines="${removeEmptyLines}v"

appendEmptyLine () {
   [ -z "$dry_run" ] && [ -z "$remove" ] && echo "" >> $1
}

installAptPackages() {
  package_list=$1
  skip_prompt=""
  [ -n "$2"] && skip_prompt="-y "
  sudo apt install ${skip_prompt}${package_list}
}

installSnapPackages() {
  package_list=($1)
  classic_mode=""
  [ -n "$2" ] && classic_mode=" --classic"
  for pack in "${package_list[@]}"; do
    sudo snap install ${pack}${classic_mode}
  done
}

###Verbose stuff
if [ -n "$verbose" ]; then
  echo "-----------------------------------------------------------------------------------------------------------"
  echo -n "Removing              : "; [ -n "$remove" ] && echo "yes" || echo "no"
  echo -n "Installing prequisites: "; [ -n "$prequisites" ] && echo "yes" || echo "no"
  echo -n "Dry run               : "; [ -n "$dry_run" ] && echo "yes" || echo "no"
  echo "Script Dir            : ${SCRIPT_DIR}"
  echo -n "Other shell config    : "; [ -n "$shellconfig" ] && echo "$shellconfig" || echo "{none}"
  echo -n "Install i3/gui        : "; [ -n "$no_i3" ] && echo "no" || echo "yes"
  echo -n "Install k8s           : "; [ -n "$remove" ] && echo "no" || echo "yes"
  echo -n "Install extra         : "; [ -n "$install_extra" ] && echo "yes" || echo "no"
  echo -n "Install work          : "; [ -n "$install_work" ] && echo "yes" || echo "no"
  echo -n "Skip backups          : "; [ -n "$no_backups" ] && echo "yes" || echo "no"
  echo -n "I3 config found       : "; [ -f "$I3_CONFIG" ] && echo "yes" || echo "no"
  echo -n "BASH config found     : "; [ -f "$BASH_CONFIG" ] && echo "yes" || echo "no"
  echo -n "ZSH config found      : "; [ -f "$ZSH_CONFIG" ] && echo "yes" || echo "no"
  echo -n "Oh-my-ZSH config found: "; [ -d "$OH_MY_ZSH_CONFIG" ] && echo "yes" || echo "no"
  echo -n "Profile config found  : "; [ -f "$PROFILE" ] && echo "yes" || echo "no"
  echo -n "Other shell found     : "; [ -f "$shellconfig" ] && echo "yes" || echo "no"
  echo "Fileline command      : ${fileLine}"
  echo "Removelines command   : ${removeEmptyLines}"
  echo "-----------------------------------------------------------------------------------------------------------"
fi


### Backupsh
if [ -z "$no_backups" ]; then
  today=$(date +%Y%m%d)

  createBackup () {
    file=$1
    [ ! -f "$file" ] && ([ -n "$verbose" ] && echo "No backup to be made, file does not exist: ${file}"; exit 0)
    [ -f "${file}.bak.${today}" ] && ([ -n "$verbose" ] && echo "No backup to be made, today's backup already exists: ${file}.bak.${today}"; exit 0)
    [ -z "$dry_run" ] && cp "$file" "${file}.bak.${today}"
  }

  echo "* creating Backups"
  createBackup $PROFILE
  [ -n "$shellconfig" ] && createBackup $shellconfig
  [ -z "$shellconfig" ] && createBackup $BASH_CONFIG && createBackup $ZSH_CONFIG
  [ -z "$no_i3 " ] && createBackup $I3_CONFIG
else
  [ -n "$verbose" ] && echo "Skipping backups"
fi


#### Install them exquisite prequisite applications:
[ -n "$prequisites" ] && [ -n "$dry_run" ] && [ -n "$verbose" ] && echo "Not installing prequisites in dry-run mode..."
[ -n "$prequisites" ] && [ -n "$remove" ] && [ -n "$verbose" ] && echo "Not installing prequisites when removing"
if [ -n "$prequisites" ] && [ -z "$remove" ] && [ -z "$dry_run" ]; then
  echo "* Installing prequisites"
  [ -n "$verbose" ] && echo "* updating current APT packages"
  sudo apt update && sudo apt dist-upgrade -y
  sudo apt autoremove -y && sudo apt clean
  [ -n "$verbose" ] && echo "* refreshing snap"
  sudo snap refresh
  [ -n "$verbose" ] && echo "* installing main/gui APT packages"
  installAptPackages "$main_packages"
  [ -z "$no_i3" ] && installAptPackages "$gui_packages"
  if [ -n "$install_extra" ]; then
    [ -n "$verbose" ] && echo "* installing extra APT packages"
    installAptPackages "$extra_packages" 
    [ -n "$verbose" ] && echo "* installing extra Snap packages"
    installSnapPackages "$extra_snap_packages"
    installSnapPackages "$extra_snap_packages_classic" 1
  fi
  if [ -n "$install_work" ]; then 
    [ -n "$verbose" ] && echo "* installing work APT packages"
    installAptPackages "$work_packages" 
    [ -n "$verbose" ] && echo "* installing work Snap packages"
    installSnapPackages "$work_snap_packages"
    installSnapPackages "$work_snap_packages_classic" 1
  fi
  [ -z "$no_k8s" ] && sudo snap install kubectl --classic
  if [ -z "$no_i3" ] && [ ! -f "$I3_CONFIG" ]; then
    echo "* initiating i3 config"
    mkdir -p $HOME/.config/i3
    cp $SCRIPT_DIR/lib/configs/i3config.conf $I3_CONFIG
  fi
  if [ ! -d "$OH_MY_ZSH_CONFIG" ]; then
    echo "* installing oh-my-zsh from Github"
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
  fi
fi

#### Some functions to add various stuff to various files
install_k8s_aliases () {
  file=$1
  echo "* Installing k8s aliases in shell config ${file}"
  appendEmptyLine $file
  $fileLine $file -- "#### Custom K8S scripts stuff ####"
  $fileLine $file -- "alias kellogs='\$SCRIPT_DIR/k8s/klog.sh'"
  $fileLine $file -- "alias klog='\$SCRIPT_DIR/k8s/klog.sh'"
  $fileLine $file -- "alias kdesc='\$SCRIPT_DIR/k8s/kdesc.sh'"
  $fileLine $file -- "alias kget='\$SCRIPT_DIR/k8s/kget.sh'"
  $fileLine $file -- "alias kwatch='\$SCRIPT_DIR/k8s/kwatch.sh'"
  $fileLine $file -- "alias krestart='\$SCRIPT_DIR/k8s/krestart.sh'"
}

install_work_aliases () {
  file=$1
  echo "* Installing work aliases in shell config ${file}"
  #--- Pluxbox stuff
  appendEmptyLine $file
  echo "* Installing PB aliases in shell config ${file}"
  $fileLine $file -- "#### Custom Pluxbox scripts stuff ####"
  $fileLine $file -k -- "export KANTOORIP=92.66.145.13"
  $fileLine $file -- "alias kssh='\$SCRIPT_DIR/pb/kssh.sh'"
  $fileLine $file -- "alias getsma='\$SCRIPT_DIR/pb/getsma.sh'"
  #End Pluxbox stuff
}

install_lib_aliases () {
  file=$1
  echo "* Installing other aliases in shell config ${file}"
  appendEmptyLine $file
  $fileLine $file -- "#### Custom scripts stuff ####"
  $fileLine $file -- "alias fileline='\$SCRIPT_DIR/lib/fileline.sh'"
  $fileLine $file -- "alias limitbw='\$SCRIPT_DIR/lib/limit-bandwith.sh'"
  $fileLine $file -- "alias ipcount='\$SCRIPT_DIR/lib/nginx-ip-count.sh'"
  $fileLine $file -- "alias whatsmyip='\$SCRIPT_DIR/lib/whatsmyip.sh'"
  $fileLine $file -- "alias remove-empty-lines='\$SCRIPT_DIR/lib/remove-empty-lines.sh'"
}

update_i3_config () {
  echo "* Adding stuff to i3 config ${I3_CONFIG}"
}


#### Let's get ready to rum... naah
echo "* Adding stuff to profile ${PROFILE}"
appendEmptyLine $PROFILE
$fileLine $PROFILE -- "#Custom scripts stuff"
$fileLine $PROFILE -k -- "export SCRIPT_DIR=\"${SCRIPT_DIR}\""
$removeEmptyLines $PROFILE

if [ -n "$shellconfig" ]; then
  install_lib_aliases $shellconfig
  $fileLine $shellconfig -- "eval \"\$(thefuck --alias)\""
  $fileLine $shellconfig -- "source ${SCRIPT_DIR}/lib/whatsmyip.sh > /dev/null #set wan ip address in env variables"

  [ -z "$no_k8s" ] && install_k8s_aliases $shellconfig
  [ -z "$no_k8s" ] && $fileLine $shellconfig -- "alias k='kubectl'"

  [ -n "$install_work" ] && install_work_aliases $shellconfig

  $removeEmptyLines $shellconfig
else
  if [ -f "$BASH_CONFIG" ];then
    install_lib_aliases $BASH_CONFIG
    $fileLine $BASH_CONFIG -- "source ${SCRIPT_DIR}/lib/whatsmyip.sh > /dev/null #set wan ip address in env variables"
    $fileLine $BASH_CONFIG -- "eval \"\$(thefuck --alias)\""

    if [ -z "$no_k8s" ]; then
      install_k8s_aliases $BASH_CONFIG
      $fileLine $BASH_CONFIG -- "alias k='kubectl'"
      $fileLine $BASH_CONFIG -- "source <(kubectl completion bash)"
      $fileLine $BASH_CONFIG -- "source <(k completion bash | sed \"s/\bkubectl\b/k/g\")"
    fi

    [ -n "$install_work" ] && install_work_aliases $BASH_CONFIG

    $removeEmptyLines $BASH_CONFIG
  fi
  if [ -f "$ZSH_CONFIG" ]; then
    $fileLine $ZSH_CONFIG -k -- "plugins=(ansible docker dotenv git golang homestead kubectl laravel microk8s npm python ssh-agent thefuck vim-interaction)"
    install_lib_aliases $ZSH_CONFIG
    $fileLine $ZSH_CONFIG -- "source ${SCRIPT_DIR}/lib/whatsmyip.sh > /dev/null #set wan ip address in env variables"

    [ -z "$no_k8s" ] && install_k8s_aliases $ZSH_CONFIG

    [ -n "$install_work" ] && install_work_aliases $ZSH_CONFIG

    $removeEmptyLines $ZSH_CONFIG
  fi
fi

if [ -n "$no_i3" ]; then
  update_i3_config
fi

