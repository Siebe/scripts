#/bin/bash

jackd -d alsa -d hw:0 -r48000 &

sleep 10

rotter -f flac -n radio1_flac /var/audio/log/radio1/ > /root/log/r1flac.log&
rotter -f mp3 -b 128 -n radio1_mp3 /var/audio/log/radio1/ > /root/log/r1mp3.log&
rotter -f flac -n radio2_flac /var/audio/log/radio2/ > /root/log/r2flac.log&
rotter -f mp3 -b 128 -n radio2_mp3 /var/audio/log/radio2/ > /root/log/r2mp3.log&
rotter -f flac -n 3fm_flac /var/audio/log/3fm/ > /root/log/r3flac.log&
rotter -f mp3 -b 128 -n 3fm_mp3 /var/audio/log/3fm/ > /root/log/r3mp3.log&
rotter -f flac -n 3fm_flac_clean /var/audio/log/3fm-clean/ > /root/log/r3cleanflac.log&
rotter -f mp3 -b 128 -n 3fm_mp3_clean /var/audio/log/3fm-clean/ > /root/log/r3cleanmp3.log&
rotter -f flac -n radio4_flac /var/audio/log/radio4/ > /root/log/r4flac.log&
rotter -f mp3 -n radio4_mp3_192 /var/audio/log/radio4_192/ > /root/log/r4192.log&
rotter -f mp3 -b 128 -n radio4_mp3 /var/audio/log/radio4/ > /root/log/r4mp3.log&
rotter -f flac -n radio5_flac /var/audio/log/radio5/ > /root/log/r5flac.log&
rotter -f mp3 -b 128 -n radio5_mp3 /var/audio/log/radio5/ > /root/log/r5mp3.log&
rotter -f flac -n radio6_flac /var/audio/log/radio6/ > /root/log/r6flac.log&
rotter -f mp3 -b 128 -n radio6_mp3 /var/audio/log/radio6/ > /root/log/r6mp3.log&
rotter -f flac -n funx_flac /var/audio/log/funx/ > /root/log/funxflac.log&
rotter -f mp3 -b 128 -n funx_mp3 /var/audio/log/funx/ > /root/log/funxmp3.log&
rotter -f flac -n 3fm_kx_flac /var/audio/log/3fm_kx/ > /root/log/3fm_kxflac.log&
rotter -f mp3 -b 128 -n 3fm_kx_mp3 /var/audio/log/3fm_kx/ > /root/log/3fm_kxmp3.log&


sleep 10

rakarrack -l /var/www/config/sites/audiobox_npo/resources/rakarrack-preset.rkr --no-gui&
rakarrack -l /var/www/config/sites/audiobox_npo/resources/rakarrack-preset.rkr --no-gui&

sleep 10

jack_disconnect system:capture_1 rakarrack:in_1
jack_disconnect system:capture_1 rakarrack:in_2
jack_disconnect system:capture_1 rakarrack-01:in_1
jack_disconnect system:capture_1 rakarrack-01:in_2
jack_disconnect rakarrack:out_1 system:playback_1
jack_disconnect rakarrack:out_2 system:playback_2
jack_disconnect rakarrack-01:out_1 system:playback_1
jack_disconnect rakarrack-01:out_2 system:playback_2

jack_connect system:capture_33 radio1_flac:left
jack_connect system:capture_33 radio1_mp3:left
jack_connect system:capture_34 radio1_flac:right
jack_connect system:capture_34 radio1_mp3:right

jack_connect system:capture_35 radio2_flac:left
jack_connect system:capture_35 radio2_mp3:left
jack_connect system:capture_36 radio2_flac:right
jack_connect system:capture_36 radio2_mp3:right

jack_connect system:capture_37 3fm_flac:left
jack_connect system:capture_37 3fm_mp3:left
jack_connect system:capture_38 3fm_flac:right
jack_connect system:capture_38 3fm_mp3:right

jack_connect system:capture_25 rakarrack-01:in_1
jack_connect system:capture_26 rakarrack-01:in_2
jack_connect rakarrack-01:out_1 3fm_mp3_clean:left
jack_connect rakarrack-01:out_2 3fm_mp3_clean:right
jack_connect rakarrack-01:out_1 3fm_flac_clean:left
jack_connect rakarrack-01:out_2 3fm_flac_clean:right

jack_connect system:capture_39 rakarrack:in_1
jack_connect system:capture_40 rakarrack:in_2
jack_connect rakarrack:out_1 radio4_flac:left
jack_connect rakarrack:out_1 radio4_mp3:left
jack_connect rakarrack:out_2 radio4_flac:right
jack_connect rakarrack:out_2 radio4_mp3:right

jack_connect system:capture_39 radio4_mp3_192:left
jack_connect system:capture_40 radio4_mp3_192:right

jack_connect system:capture_41 radio5_flac:left
jack_connect system:capture_41 radio5_mp3:left
jack_connect system:capture_42 radio5_flac:right
jack_connect system:capture_42 radio5_mp3:right

jack_connect system:capture_43 radio6_flac:left
jack_connect system:capture_43 radio6_mp3:left
jack_connect system:capture_44 radio6_flac:right
jack_connect system:capture_44 radio6_mp3:right

jack_connect system:capture_45 funx_flac:left
jack_connect system:capture_45 funx_mp3:left
jack_connect system:capture_46 funx_flac:right
jack_connect system:capture_46 funx_mp3:right

jack_connect system:capture_55 3fm_kx_flac:left
jack_connect system:capture_55 3fm_kx_mp3:left
jack_connect system:capture_56 3fm_kx_flac:right
jack_connect system:capture_56 3fm_kx_mp3:right
