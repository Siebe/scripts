#!/usr/bin/env bash

usage () {
  echo 'Count number of requests per ip address in nginx logfile. Usage:'
	echo ' ./nginx-ip-count.sh [-hv] [-g GATECOUNT] [LOGFILE]'
	echo '-g GATECOUNT = only show addresses with minimun count, default=1000'
	echo 'LOGFILE = logfile to analyze, default="/var/log/nginx/access.log"'
	echo '-v = verbose mode'
}

while getopts "hvg:" options
do
	case $options in
		h ) usage; exit 0;;
   	g ) gate="${OPTARG}";;
    v ) verbose=1;;
    ? ) echo 'Error: invalid option'; usage; exit 1;;
	esac
done

shift $(($OPTIND - 1))
logfile="$1"

[ -z "$gate" ] && gate=1000
[ -z "$logfile" ] && logfile="/var/log/nginx/access.log"

[ -n "$verbose" ] && echo "Ouput gate : ${gate}"
[ -n "$verbose" ] && echo "Logfile:   : ${logfile}"
unique_addresses=($(grep -Po "^(\d{1,3}\.){3}\d{1,3}" ${logfile} | sort | uniq))

[ -n "$verbose" ] && echo "Total unique addresses found: ${#unique_addresses[@]}"

for i in "${unique_addresses[@]}"; do
  c=`grep -c "^$i" ${logfile}`
  if [ $c -gt "$gate" ]; then
    echo $c - $i
  fi
done