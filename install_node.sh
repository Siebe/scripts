#!/usr/bin/env bash

print_help () {
	echo 'usage: ./install_node.sh [-r] '
	echo 'use -r for removal'
	exit 0	
}

remove=0

while getopts "rh" options
do
	case $options in
   	r ) remove=1;;
		h ) print_help;;
	esac
done

if [ $remove -ne 1 ]  ; then
	echo installing nvm and node
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash
  export NVM_DIR=$HOME/.nvm;
  source $NVM_DIR/nvm.sh;
  nvm install stable
else 
	echo removing nvm and node
  read -p "Continue (y/n)?" choice
case "$choice" in 
  y|Y ) echo "yes";;
  n|N ) echo "no";exit 0;;
  * ) echo "invalid";exit 1;;
esac
  nvm_dir="${NVM_DIR:-$HOME/.nvm}"
  source $nvm_dir/nvm.sh
  nvm unload
  rm -rf "$nvm_dir"
fi
