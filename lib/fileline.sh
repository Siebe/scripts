#!/usr/bin/env bash

usage () {
  echo 'Append string to file if the string is not yet present or remove string if present. Usage:'
	echo ' ./fileline.sh [-rkavd] [-K separator] -f FILENAME -- STRING'
	echo '-f FILENAME = path to file'
	echo 'STRING = string to add or remove'
	echo '-r = remove string from file if present'
	echo '-k = match by key and replace string instead of append if key exists (for changing or removing key/value inputs)'
	echo '-K SEPARATOR = key/value separator, including spaces (default "=", e.g. "mykey=myvalue")'
	echo '-a = replace or remove all matches'
	echo '-v = verbose mode'
	echo '-d = dry-run'
}

examples () {
  echo ""
  echo "Examples:"
  echo "Append a input to a config file if it is not present yet:"
  echo "./fileline.sh -f ~/myconfig.conf -- This is a new input"
  echo ""
  echo "Remove a input from a config file if it is present:"
  echo "./fileline.sh -rf /etc/someconfig.conf -- This input will be removed"
  echo ""
  echo "Change a key value setting or append it if not present yet:"
  echo "./fileline.sh -kf /tmp/tmpconfig.conf -- foo=bar"
  echo ""
  echo "Change a key value setting, but its separator is different (eg \": \"):"
  echo "./fileline.sh -k -K \" : \" -f /home/user/myconfig.conf -- foo: bar"
  echo ""
  echo "Remove all entries with the key \"foo\":"
  echo "./fileline.sh -ark -f ~/myconfig.conf -- foo"
}

separator="="

while getopts ":hrkaK:f:vd" options
do
	case $options in
			h ) usage; examples; exit 0;;
   		r ) remove=1;;
      k ) by_key=1;;
      a ) all_matches=1;;
      K ) separator="${OPTARG}";;
      f ) file="${OPTARG}";;
      v ) verbose=1;;
      d ) dry_run=1;;
      ? ) echo 'Error: invalid option'; usage; exit 1;;
	esac
done

#using curly instead of parenthesis because then exit 1 doesn't only exit child
[ -z "$file" ] && { >&2 echo 'Error: FILENAME required'; usage; exit 1; }
[ ! -f $file ] && { >&2 echo 'Error: FILENAME should be valid path to file'; usage; exit 1; }
[ -z "$separator" ] && { >&2 echo 'Error: separator can not be empty'; usage; exit 1; }

shift $(($OPTIND - 1))
input="$@"
regexsafe_input=${input//\//\\/}

[ -z "$input" ] && { >&2 echo 'Error: STRING required'; usage; exit 1; }

input_linecount=$(echo "$input" | wc -l)

#TODO handle multple lines for not by key
if [ "$input_linecount" -gt "1" ]; then
  >&2 echo "Error: cannot handle multiple lines of input"; usage; exit 1;
fi

if [ -n "$by_key" ]; then
  extracted_key=''
  # match by key. if replace, expect the separator in the match input. if remove separator is not mandatory
  if [[ $input == *"$separator"* ]] || [ -n "$remove" ]; then
      #this is "explode" in BASH
      IFS="$separator" read -ra key_value_array <<< "$input"
      extracted_key=${key_value_array[0]}
  else
      >&2 echo "Error: separator \"$separator\" not found in input"; usage; exit 1;
  fi
  [ -z "$extracted_key" ] && { >&2 echo "Error: No key name found before separator \"$separator\""; usage; exit 1; }
  search_string="$extracted_key$separator"
  regexsafe_search_string=${search_string//\//\\/}
  match_lines=($(grep -n "^\s*${regexsafe_search_string}" $file | cut -d : -f 1))
else
  search_string=$input
  match_lines=($(grep -nxF "${search_string}" $file | cut -d : -f 1))
fi


match_count=${#match_lines[@]}

if [ -n "$verbose" ]; then
  fullpath=$(realpath "$file")
  echo "File            : \"$fullpath\""
  echo "Input string    : \"$input\""
  echo "Input regexsafe : \"$regexsafe_input"
  echo "Input linecount : \"$input_linecount\""
  echo -n "Removing        : "; [ -z "$remove" ] && echo "no" || echo "yes"
  echo -n "All matches     : "; [ -z "$all_matches" ] && echo "no" || echo "yes"
  if [ -z "$by_key" ]; then
    echo "Match by key    : no"
  else
    echo "Match by key    : yes"
    echo "Key separator   : \"$separator\""
    echo "Extracted key   : \"$extracted_key\""
  fi
  echo "Search string   : \"$search_string\""
  echo "Match count     : $match_count"
  echo -n "Matching Lines  : "; [ -z "$all_matches" ] && echo ${match_lines[0]} || echo ${matchin_inputs[*]}
  echo -n "Dry run         : "; [ -z "$dry_run" ] && echo "no" || echo "yes"
fi

#The no-need-to-do-anything situations:
if [ -n "$remove" ] && [ "$match_count" -eq "0" ]; then
  [ -n "$verbose" ] && echo "String \"$search_string\" not found in $fullpath"
  exit 0 #trying to remove but no matches
fi
if [ -z "$remove" ] && [ -z "$by_key" ] && [ "$match_count" -gt "0" ]; then
  [ -n "$verbose" ] && echo "String \"$search_string\" already present in $fullpath"
  exit 0 #trying to append but already present
fi
if [ -z "$remove" ] && [ -n "$by_key" ] && [ -z "$all_matches" ] && [ "$match_count" -gt "0" ]; then
  #trying add/update by key, single match. Check whether the exact key value combination is present
  if grep -qxF "$input" $file ; then
     [ -n "$verbose" ] && echo "String \"$input\" already present in $fullpath"
     exit 0
  fi
fi

if [ -z "$remove" ]; then
  if [ -n "$by_key" ] && [ "$match_count" -gt "0" ]; then
    [ -n "$verbose" ] && echo "Replacing in $fullpath"
    if [ -n "$all_matches" ]; then
      for line_number in "${match_lines[@]}"; do
        [ -n "$verbose" ] && echo "Replacing line $line_number with $regexsafe_input"
        [ -z "$dry_run" ] && sed -i "${line_number}s/.*/${regexsafe_input}/g" $file
      done
    else
      [ -n "$verbose" ] && echo "Replacing line ${match_lines[0]} with $regexsafe_input"
      [ -z "$dry_run" ] && sed -i "${match_lines[0]}s/.*/${regexsafe_input}/g" $file
    fi
  else
    [ -n "$verbose" ] && echo "Appending file $fullpath with $input"
    [ -z "$dry_run" ] && echo "$input" >> $file
  fi
else
  [ -n "$verbose" ] && echo "Removing in $fullpath"

  for line_number in "${match_lines[@]}"; do
    end_line_number=$(( $line_number + $input_linecount ))
    [ -n "$verbose" ] && echo "Removing line $line_number to $end_line_number"
    [ -z "$dry_run" ] && sed -ie "${line_number},${end_line_number}d" $file
    #no multi match? no match by key? only remove one line, so exit loop
    [ -z "$all_matches" ] && exit 0
  done

fi
