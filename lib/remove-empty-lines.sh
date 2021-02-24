#!/usr/bin/env bash

usage () {
  echo 'Remove empty lines from top and bottom of file. Usage:'
	echo ' ./remove-empty-lines.sh [-hTBvd] FILE'
	echo '-T = top only'
	echo '-B = bottom only'
	echo 'FILE = the text file'
	echo '-v = verbose mode'
	echo '-d = dry run'
}

while getopts "hTBvd" options
do
	case $options in
		h ) usage; exit 0;;
   	T ) toponly=1;;
    B ) bottomonly=1;;
    v ) verbose=1;;
    d ) dry_run=1;;
    ? ) echo 'Error: invalid option'; usage; exit 1;;
	esac
done

shift $(($OPTIND - 1))
file="$1"

[ ! -f "$file" ] && { >&2 echo 'Error: FILE needs to be a file'; usage; exit 1; }
[ -n "$toponly" ] && [ -n "$bottomonly" ] && toponly="" && bottomonly=""

content="$(cat $file)"

if [ -z "$toponly"]; then
  linecount=$(grep -Poz "\n+$" $file | wc -l)
  linecount=$(expr $linecount - 1)
  [ -n "$verbose" ] && echo "found ${linecount} empty line(s) at bottom of file"
  if [ "$linecount" -gt "0" ]; then
    linearg="-n -${linecount}"
    content="$(head $linearg $file)"
    [ -z "$dry_run" ] && echo "$content" > $file
  fi
fi

#OK SO "tail -n -1" does not work, no negative numbers.. but head is ok with it.. wtf...
if [ -z "$bottomonly" ]; then
  totallinecount=$(cat $file | wc -l)
  linecount=$(grep -Poz "^\n+" $file | wc -l)
  [ -n "$verbose" ] && echo "found ${linecount} empty line(s) at top of file"
  if [ "$linecount" -gt "0" ]; then
    linearg=$(expr $totallinecount - $linecount)
    content="$(tail -n linearg $file)"
    [ -z "$dry_run" ] && echo "$content" > $file
  fi
fi


exit