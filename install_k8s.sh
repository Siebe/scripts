#!/usr/bin/env bash

print_help () {
	echo 'usage: ./install_k8s.sh [-r] [file default=~/.bashrc]'
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

shift $(($OPTIND - 1))

if [ -n "$1" ]; then
	file=$1
else 
	file="$HOME/.bashrc"
fi

add_to_file_if_not_exist () {
	grep -qxF "$2" $1 || echo "$2" >> $1
}

if [ $remove -ne 1 ]  ; then
	echo installing k8s scripts
	add_to_file_if_not_exist $file 'alias kdesc=$SCRIPTS_DIR/k8s/kdesc.sh'
	add_to_file_if_not_exist $file 'alias kget=$SCRIPTS_DIR/k8s/kget.sh'
	add_to_file_if_not_exist $file 'alias klog=$SCRIPTS_DIR/k8s/klog.sh'
	add_to_file_if_not_exist $file 'alias kreset=$SCRIPTS_DIR/k8s/kreset.sh'
	add_to_file_if_not_exist $file 'alias kwatch=$SCRIPTS_DIR/k8s/kwatch.sh'
	exec $file
else
	echo removing k8s scripts
	sed -i '/^alias kdesc=\$SCRIPTS_DIR\/k8s\/kdesc\.sh$/d' $file
	sed -i '/^alias kget=\$SCRIPTS_DIR\/k8s\/kget\.sh$/d' $file
	sed -i '/^alias klog=\$SCRIPTS_DIR\/k8s\/klog\.sh$/d' $file
	sed -i '/^alias kreset=\$SCRIPTS_DIR\/k8s\/kreset\.sh$/d' $file
	sed -i '/^alias kwatch=\$SCRIPTS_DIR\/k8s\/kwatch\.sh$/d' $file
	shopt -s expand_aliases
	unalias kdesc
fi
