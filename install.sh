#!/usr/bin/env bash

usage () {
  echo "Install my awesome selection of packages, scripts and configs, usage:"
  echo "./install.sh [-egwBdvv] [-f SHELLCONFIG]"
  echo "-r remove instead of install"
  echo "-f SHELLCONFIG: path to shell config file, zsh AND bash by default"
  echo "-a: install everything!"
  echo "-e: install extra moar packages and config"
  echo "-g: install gui (i3) packages and config"
  echo "-w: install work packages and config"
  echo "-B: no backups"
  echo "-d: dry-run"
  echo "-v: verbose mode"
  echo "-vv: deep verbose mode"
}

main_packages="curl cowsay gcc make node ntp python3-dev python3-pip vim git rustup unrar unzip xclip ohmyzsh"
extra_packages="alacritty npm:bash-language-server cargo:bluetui docker.io npm:eslint ffmpeg gzip imagemagick"
extra_packages+=" jq nmap nvchad pkg-config rsync shellcheck sox traceroute whois"

gui_packages="blueman compton i3 i3blocks i3lock fonts-font-awesome feh mpv redshift rofi scrot xautolock xdotool"
extra_gui_packages="brave gedit mixxx nmap pinta pavucontrol rsync sox wine winetricks vlc"

work_packages="ansible doctl docker.io git-secret helm jq kubectl nmap rsync traceroute whois wireguard yq"
work_gui_packages="firefox google-chrome-stable insomnia nagstamon phpstorm postman"

while getopts ":hrm:f:agewBvd" options
do
	case $options in
    h ) usage; exit 0;; #help duh
    r ) remove=1;; # Removal instead of installation, no prequisites
    f ) shellconfig="${OPTARG}";;
    a ) install_gui=1;install_extra=1;install_work=1;;
    g ) install_gui=1;;
    e ) install_extra=1;;
    w ) install_work=1;;
    B ) no_backups=1;;
    v ) [ "$verbose" -eq 1 ] && verbose=2 || verbose=1;;
    d ) dry_run=1;;
    ? ) { >&2 echo 'Error: invalid option'; usage; exit 1; };;
	esac
done


### Globals
SCRIPT_DIR=$(dirname "$(realpath "$0")")
export SCRIPT_DIR
PROFILE=$HOME/.profile
BASH_CONFIG=$HOME/.bashrc
ZSH_CONFIG=$HOME/.zshrc
OH_MY_ZSH_CONFIG=$HOME/.oh-my-zsh
I3_CONFIGDIR=$HOME/.config/i3
I3BLOCKS_CONFIGDIR=$HOME/.config/i3block
ALACRITTY_CONFIGDIR=$HOME/.config/alacritty
NVIM_CONFIGDIR=$HOME/.config/nvim

### Pre-flight-checks
[ -n "$verbose" ] && echo "Running preflight checks"
( type apt &>/dev/null ) || { >&2 echo "Error: want to install stuff, but apt not found!"; usage; exit 1; }
type snap &>/dev/null || echo "Warning: want to install sfuff, but snap not found!";
if [ ! -f "$PROFILE" ]; then
  #guess we *could* fallback to /.login i dunno
  echo "Warning: PROFILE file not found: ${HOME}/.profile, trying ${HOME}/.login"
  PROFILE=$HOME/.login
  [ ! -f "$PROFILE" ] && { >&2 echo "Error: PROFILE file not found: ${PROFILE}"; usage; exit 1; }
fi
if [ ! -f "$BASH_CONFIG" ] && [ ! -f "$ZSH_CONFIG" ] && [ ! -f "$shellconfig" ]; then
    >&2 echo "Error: Not a single shell config file found, no zsh, no bash, no nothin'"; usage; exit 1;
fi
if [ -n "$shellconfig" ] && [ ! -f "$shellconfig" ]; then
  echo "Warning: can not find shell config file ${shellconfig}, so not doing that one today."
  shellconfig="";
fi
[ -n "$verbose" ] && echo "Finished preflight checks"


### Prepare the flags for the beautiful $fileLine command:
[ -n "$verbose" ] && echo "Preparing fileline command"
fileLine="$SCRIPT_DIR/lib/fileline.sh -"
[ -n "$remove" ] && fileLine="${fileLine}r"
[ -n "$dry_run" ] && fileLine="${fileLine}d"
[ -n "$verbose" ] && fileLine="${fileLine}v"
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

installPackages() {
  package_list=($1)
  installer_flags="-y"
  [ -n "$dry_run" ] && installer_flags="${installer_flags}d"
  [ -n "$verbose" ] && installer_flags="${installer_flags}v"
  [ -n "$remove" ] && installer_flags="${installer_flags}r"
  for pack in "${package_list[@]}"; do
    "$SCRIPT_DIR/lib/app_installer.sh" "$installer_flags" "$pack"
  done
}

install_font_zip_from_url() {
  font_repo=$1
  file_name=${font_repo##*/}
  [ -n "$dry_run" ] || [ -n "$remove" ] && return 0
  this_path=$(pwd)
  FONT_PATH=${FONT_PATH-$HOME/.local/share/fonts}
  [[ "$file_name" =~ \.zip$ ]] || { >&2 echo "$font_repo does not seem to be a zipfile"; return 1; }
  mkdir -p "$FONT_PATH"
  cd "$FONT_PATH" || { >&2 echo "could not create path $FONT_PATH"; return 1; }
  command wget "$font_repo"
  echo "${FONT_PATH}/${file_name}"
  if ! [ -f "${FONT_PATH}/${file_name}" ]; then
    >&2 "unable to download file frome $font_repo"
    cd "$this_path" || { >&2 echo "could not return to path $this_path"; exit 1; }
    return 1;
  fi
  echo "* installing font ${file_name}"
  command unzip "$file_name"
  command rm "$file_name"
  command fc-cache -f
  command cd "$this_path"
}


#### Function to configure everything

installWorkAliases () {
  file=$1
  echo "* Installing work aliases in shell config ${file}"
  #--- Pluxbox stuff
  appendEmptyLine $file
  echo "* Installing PB aliases in shell config ${file}"
  $fileLine $file -- "#### Custom Pluxbox scripts stuff ####"
  $fileLine $file -- "alias kssh='\$SCRIPT_DIR/pb/kssh.sh'"
  $fileLine $file -- "alias getsma='\$SCRIPT_DIR/pb/getsma.sh'"
  #End Pluxbox stuff
  appendEmptyLine $file
  $fileLine $file -- "#### Custom K8S scripts stuff ####"
  $fileLine $file -- "alias kellogs='\$SCRIPT_DIR/k8s/klog.sh'"
  $fileLine $file -- "alias klog='\$SCRIPT_DIR/k8s/klog.sh'"
  $fileLine $file -- "alias kdesc='\$SCRIPT_DIR/k8s/kdesc.sh'"
  $fileLine $file -- "alias kget='\$SCRIPT_DIR/k8s/kget.sh'"
  $fileLine $file -- "alias kwatch='\$SCRIPT_DIR/k8s/kwatch.sh'"
  $fileLine $file -- "alias krestart='\$SCRIPT_DIR/k8s/krestart.sh'"

}

installLibAliases () {
  file=$1
  echo "* Installing other aliases in shell config ${file}"
  appendEmptyLine $file
  $fileLine $file -- "#### Custom scripts stuff ####"
  $fileLine $file -- "alias fileline='\$SCRIPT_DIR/lib/fileline.sh'"
  $fileLine $file -- "alias limitbw='\$SCRIPT_DIR/lib/limit-bandwith.sh'"
  $fileLine $file -- "alias ipcount='\$SCRIPT_DIR/lib/nginx-ip-count.sh'"
  $fileLine $file -- "alias whatsmyip='\$SCRIPT_DIR/lib/whatsmyip.sh'"
  $fileLine $file -- "alias remove-empty-lines='\$SCRIPT_DIR/lib/remove-empty-lines.sh'"
  $fileLine $file -- "alias inst='\$SCRIPT_DIR/lib/app_installer.sh'"
}

installMainConfiguration() {
  if [ -n "$shellconfig" ]; then
    installLibAliases "$shellconfig"
  else
    if [ -f "$BASH_CONFIG" ];then
      installLibAliases "$BASH_CONFIG"
    fi
    if [ -f "$ZSH_CONFIG" ]; then
      echo "* Setting ZSH as default shell"
      command which zsh > /dev/null && command sudo chsh -s "$(which zsh)" "$USER"
      installLibAliases "$ZSH_CONFIG"
    fi
  fi
}

installExtraConfiguration() {
  if [ -n "$shellconfig" ] && [ -f "$ZSH_CONFIG" ]; then
      echo "* Configuring Oh My Zsh plugins"
      $fileLine "$ZSH_CONFIG" -k -- "plugins=(ansible composer docker doctl docker-compose dotenv git helm kubectl laravel nvm npm rsync rust ssh-agent ufw vim-interaction)"
  fi
  if [ -z "$dry_run" ] && [ -z "$remove" ]; then
    echo "* Configuring Alacritty"
    command mkdir -p "$ALACRITTY_CONFIGDIR"
    command cp "$SCRIPT_DIR/resources/configs/alacritty.toml" "$ALACRITTY_CONFIGDIR/alacritty.toml"
    command cp "$SCRIPT_DIR/resources/configs/alacritty-theme.toml" "$ALACRITTY_CONFIGDIR/alacritty-theme.toml"
    echo "* Configuring nvim"
    command mkdir -p "$NVIM_CONFIGDIR"
    command cp -r "$SCRIPT_DIR"/resources/configs/nvim/* "$NVIM_CONFIGDIR/."
    install_font_zip_from_url 'https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/Cousine.zip'
    command nvim --headless '+Lazy! sync' '+qa'
    command nvim --headless '+MasonToolsUpdateSync' '+qa'
  fi
}

installGuiConfiguration() {
  if [ -z "$dry_run" ] && [ -z "$remove" ]; then
    echo "* Configuring i3 and i3blocks"
    command mkdir -p "$I3_CONFIGDIR"
    command mkdir -p "$I3BLOCKS_CONFIGDIR"
    command cp "$SCRIPT_DIR/resources/configs/i3config.conf" "$I3_CONFIGDIR/config"
    command cp "$SCRIPT_DIR/resources/configs/i3blocks.conf" "$I3BLOCKS_CONFIGDIR/config"
    command i3-msg reload
  fi
}

installWorkConfiguration() {
  if [ -n "$shellconfig" ]; then
    installWorkAliases "$shellconfig"
  else
    if [ -f "$BASH_CONFIG" ];then
      installWorkAliases "$BASH_CONFIG"
      $fileLine $BASH_CONFIG -- "alias k='kubectl'"
      $fileLine $BASH_CONFIG -- "source <(kubectl completion bash)"
      $fileLine $BASH_CONFIG -- "source <(k completion bash | sed \"s/\bkubectl\b/k/g\")"
    fi
    if [ -f "$ZSH_CONFIG" ]; then
      installWorkAliases "$ZSH_CONFIG"
    fi
  fi
}

###Verbose stuff
if [ -n "$verbose" ]; then
  echo "-----------------------------------------------------------------------------------------------------------"
  echo "HOME                  : ${HOME}"
  echo "USER                  : ${USER}"
  echo -n "Removing              : "; [ -n "$remove" ] && echo "yes" || echo "no"
  echo -n "Dry run               : "; [ -n "$dry_run" ] && echo "yes" || echo "no"
  echo "Script Dir            : ${SCRIPT_DIR}"
  echo -n "Other shell config    : "; [ -n "$shellconfig" ] && echo "$shellconfig" || echo "{none}"
  echo -n "Install i3/gui        : "; [ -n "$install_gui" ] && echo "yes" || echo "no"
  echo -n "Install extra         : "; [ -n "$install_extra" ] && echo "yes" || echo "no"
  echo -n "Install work          : "; [ -n "$install_work" ] && echo "yes" || echo "no"
  echo -n "Skip backups          : "; [ -n "$no_backups" ] && echo "yes" || echo "no"
  echo -n "i3 configdir found    : "; [ -d "$I3_CONFIGDIR" ] && echo "yes" || echo "no"
  echo -n "i3blocks configdir... : "; [ -d "$I3_CONFIGDIR" ] && echo "yes" || echo "no"
  echo -n "Alacritty configdir.. : "; [ -d "$ALACRITTY_CONFIGDIR" ] && echo "yes" || echo "no"
  echo -n "BASH config found     : "; [ -f "$BASH_CONFIG" ] && echo "yes" || echo "no"
  echo -n "ZSH config found      : "; [ -f "$ZSH_CONFIG" ] && echo "yes" || echo "no"
  echo -n "Oh-my-ZSH config found: "; [ -d "$OH_MY_ZSH_CONFIG" ] && echo "yes" || echo "no"
  echo -n "Nvim configdir found  : "; [ -d "$NVIM_CONFIGDIR" ] && echo "yes" || echo "no"
  echo -n "Profile config found  : "; [ -f "$PROFILE" ] && echo "yes" || echo "no"
  echo -n "Other shell found     : "; [ -f "$shellconfig" ] && echo "yes" || echo "no"
  echo "Fileline command      : ${fileLine}"
  echo "Removelines command   : ${removeEmptyLines}"
  echo "-----------------------------------------------------------------------------------------------------------"
fi


### Backups
if [ -z "$no_backups" ]; then
  today=$(date +%Y%m%d)

  createBackup () {
    path=$1
    if [ ! -f "$path" ] && [ ! -d "$path" ]; then
      [ -n "$verbose" ] && echo "No backup to be made, path does not exist: ${path}";
      return 1
    fi
    [ -f "${file}.bak.${today}" ] &&\
     ([ -n "$verbose" ] && echo "No backup to be made, today's backup already exists: ${path}.bak.${today}"; exit 0)
    [ -n "$dry_run" ] && return 0
    [ -f "$path" ] && cp "$path" "${path}.bak.${today}"
    [ -d "$path" ] && cp -r "$path" "${path}.bak.${today}"
  }

  echo "* creating Backups"
  createBackup $PROFILE
  if [ -n "$shellconfig" ]; then
    createBackup "$shellconfig"
  else
    [ -f "$BASH_CONFIG" ] && createBackup "$BASH_CONFIG"
    [ -f "$ZSH_CONFIG" ] && createBackup "$ZSH_CONFIG"
  fi
  [ -n "$install_gui" ] && [ -f "$I3_CONFIGDIR/config" ] && createBackup "$I3_CONFIGDIR/config"
  [ -n "$install_gui" ] && [ -f "$I3BLOCKS_CONFIGDIR/config" ] && createBackup "$I3BLOCKS_CONFIGDIR\config"
  if [ -n "$install_extra" ]; then
    [ -f "$ALACRITTY_CONFIGDIR/alacritty.toml" ] && createBackup "$ALACRITTY_CONFIGDIR/alacritty.toml"
    [ -f "$ALACRITTY_CONFIGDIR/alacritty-theme.toml" ] && createBackup "$ALACRITTY_CONFIGDIR/alacritty-theme.toml"
    [ -d "$NVIM_CONFIGDIR" ] && createBackup "$NVIM_CONFIGDIR"
   fi
else
  [ -n "$verbose" ] && echo "Skipping backups"
fi

#### Let's get ready to rum... naah
echo "* Adding stuff to profile ${PROFILE}"
appendEmptyLine $PROFILE
$fileLine $PROFILE -- "#Custom scripts stuff"
$fileLine $PROFILE -k -- "export SCRIPT_DIR=\"${SCRIPT_DIR}\""
$removeEmptyLines $PROFILE

echo "* Installing main packages"
installPackages "$main_packages"
echo "* Installing main configurations"
installMainConfiguration
if [ -n "$install_gui" ]; then
  echo "* Installing gui(i3) packages"
  installPackages "$gui_packages"
  echo "* Installing gui(i3) configuration"
  installGuiConfiguration
fi
if [ -n "$install_extra" ]; then
  echo "* Installing extra packages"
  installPackages "$extra_packages"
  echo "* Installing extra configurations"
  installExtraConfiguration
  if [ -n "$install_gui" ]; then
    echo "* Installing extra gui packages"
    installPackages "$extra_gui_packages"
  fi
fi
if [ -n "$install_work" ]; then
  echo "* Installing work packages"
  installPackages "$work_packages"
  echo "* Installing work configuration"
  installWorkConfiguration
  if [ -n "$install_gui" ]; then
    echo "* Installing work gui packages"
    installPackages "$work_gui_packages"
  fi
fi

echo "* Ktnxbye"