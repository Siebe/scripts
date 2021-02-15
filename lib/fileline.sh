#/usr/bin/env bash]

usage () {
  echo 'Append line to file if the line is not yet present or remove line if present. Usage:'
	echo ' ./fileline.sh [-rv] -f FILENAME -- LINE'
	echo '-f FILENAME = path to file'
	echo '-r = remove line from file if present'
	echo '-v = verbose mode'
	echo 'LINE = string to add or remove'
}

while getopts ":hrf:v" options
do
	case $options in
			h ) usage; exit 0;;
   		r ) remove=1;;
      f ) file="${OPTARG}";;
      v ) verbose=1;;
      ? ) echo 'Error: invalid option'; usage; exit 1;;
	esac
done

#using curly instead of parenthesis because then exit 1 doesn't only exit child
[ -z "$file" ] && { >&2 echo 'Error: FILENAME required'; usage; exit 1; }
[ ! -f $file ] && { >&2 echo 'Error: FILENAME should be valid path to file'; usage; exit 1; }

shift $(($OPTIND - 1))
line="$@"

[ -z "$line" ] && { >&2 echo 'Error: LINE required'; usage; exit 1; }

if [ ! -z "$verbose" ]; then
  fullpath=$(realpath "$file")
  echo "File    : $fullpath"
  echo "Line    : $line"
  echo -n "Removing: "; [ -z "$remove" ] && echo "no" || echo "yes"
fi

if [ -z "$remove" ]; then
  #find line in file, if not found append line to file
  if $(grep -qxF "$line" $file); then
    [ -z "$verbose" ] || echo "Line \"$line\" already in $fullpath"
  else
    [ -z "$verbose" ] || echo "Appending \"$line\" to $fullpath"
    echo "$line" >> $file
  fi
else
  #find line in file, if found only get the line number
  linenumber=$(grep -m 1 -nxF "$line" $file | cut -d : -f 1)
  if [ "$linenumber" = "" ]; then
    [ -z "$verbose" ] || echo "Line \"$line\" not found in $fullpath"
  else
    [ -z "$verbose" ] || echo "Removing \"$line\" on linenumber $linenumber from $fullpath"
    sed -ie "${linenumber}d" $file
  fi
fi