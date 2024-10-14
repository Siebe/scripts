#!/usr/bin/env bash

print_help() {
  echo 'usage: ./install_nvchad.sh [-r] '
  echo 'use -r for removal'
  exit 0
}


install_font_zip_from_url() {
  font_repo=$1
  file_name=${font_repo##*/}
  this_path=$(pwd)
  FONT_PATH=${FONT_PATH-$HOME/.local/share/fonts}
  [[ "$file_name" =~ \.zip$ ]] || { >&2 echo "$font_repo does not seem to be a zipfile"; return 1; }
  mkdir -p "$FONT_PATH" 
  cd "$FONT_PATH" || { >&2 echo "could not create path $FONT_PATH"; return 1; }
  wget "$font_repo"
  echo "${FONT_PATH}/${file_name}"
  if ! [ -f "${FONT_PATH}/${file_name}" ]; then 
    >&2 "unable to download file frome $font_repo" 
    cd "$this_path" || { >&2 echo "could not return to path $this_path"; exit 1; } 
    return 1; 
  fi
  unzip "$file_name"
  rm "$file_name"
  fc-cache -f
}

remove=0

while getopts "rh" options; do
  case $options in
  r) remove=1 ;;
  h) print_help ;;
  esac
done
x

if [ $remove -ne 1 ]; then
  echo installing Neovim
  sudo add-apt-repository ppa:neovim-ppa/unstable
  sudo apt update && sudo apt install -y neovim github

  echo installing bash-language-server
  $SCRIPT_DIR/install_node.sh
  nvm_dir="${NVM_DIR:-$HOME/.nvm}"
  source $nvm_dir/nvm.sh
  npm -g install bash-language-server

  echo install fonts
  install_font_zip_from_url 'https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/Cousine.zip'

  echo install NvChad
  git clone https://github.com/NvChad/starter ~/.config/nvim
  nvim --headless -c 'MasonUpdate' -c qall
  nvim --headless -c 'MasonInstall lua-language_server' -c qall
  nvim --headless -c 'MasonInstall css-lsp' -c qall
  nvim --headless -c 'MasonInstall html-lsp' -c qall
  nvim --headless -c 'MasonInstall bash-language-server' -c qall
else
  echo removing k8s scripts
fi
