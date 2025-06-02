for DIR in /var/audio/log/{3fm,radio1,radio2,radio4,radio5,radio6,funx}/201{0,1,2,3}/
do
        nice -n +18 rsync -av "${DIR}" "192.168.2.2:${DIR}" 
done

