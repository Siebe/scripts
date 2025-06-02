filename="$1"
mp3_filename="$(echo ${filename} | sed 's/flac.corrupt$/mp3/')"



mp3_duration=$(soxi -D $mp3_filename 2>/dev/null|python -c "print round(float(raw_input()))")
flac_duration=$(soxi -D $filename|python -c "print round(float(raw_input()))")

echo "FLAC $flac_duration MP3 $mp3_duration"
