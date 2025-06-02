#!/bin/bash

#
# This script checks if Soxi is able to parse the file and rename the file to
# .corrupt if the duration is < 3599 seconds (0:59:59)
#
# You can call it using find(1) like so:
#
# $ find /var/audio/log/*/2014/03/ -name 'archive.flac' -exec ./corrupt_audio_files.sh {} \; > 2014_03_corrupt_flac.log

filename="${1}"

rename_file() {
	echo "Rename ${filename} to ${filename}.corrupt"
	mv "${filename}" "${filename}.corrupt"
}

duration="$(soxi -D $filename 2>/dev/null)"
if [[ "$?" != "0" ]];
then
	rename_file
fi
if [[ "$duration" = "0" ]];
then
	echo "Couldn't parse duration."
	exit 1
fi

if [[ $(echo "${duration} < 3599" | bc) -eq 1 ]]
then
	rename_file
fi


