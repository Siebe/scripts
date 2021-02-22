#!/usr/bin/env bash

set -euo pipefail
#
# Originally from https://www.iplocation.net/traffic-control
#
#TODO: Test http://www.tldp.org/HOWTO//Adv-Routing-HOWTO/lartc.ratelimit.single.html ?
# Name of the traffic control command.
TC=/sbin/tc
# The network interface we're planning on limiting bandwidth.
IF=vboxnet0 # Interface
# Download limit (in mega bits)
DNLD=5kbit # DOWNLOAD Limit
# Upload limit (in mega bits)
UPLD=5kbit # UPLOAD Limit
# Filter options for limiting the intended interface.
U32="$TC filter add dev $IF protocol ip parent 1:0 prio 1 u32"
start() {
  $TC qdisc add dev $IF root handle 1: htb default 30
  $TC class add dev $IF parent 1: classid 1:1 htb rate $DNLD ceil $DNLD
  $TC class add dev $IF parent 1: classid 1:2 htb rate $UPLD ceil $UPLD
  $U32 match ip dst 0.0.0.0/0 flowid 1:1
  $U32 match ip src 0.0.0.0/0 flowid 1:2
  # The first line creates the root qdisc, and the next two lines
  # create two child qdisc that are to be used to shape download
  # and upload bandwidth.
  #
  # The 4th and 5th line creates the filter to match the interface.
  # The 'dst' IP address is used to limit download speed, and the
  # 'src' IP address is used to limit upload speed.
}
stop() {
  $TC qdisc del dev $IF root
}
restart() {
  stop
  sleep 1
  start
}
show() {
  $TC -s qdisc ls dev $IF
}
case "$1" in
  start)
  echo -n "Starting bandwidth shaping: "
  start
  echo "done"
  ;;
  stop)
  echo -n "Stopping bandwidth shaping: "
  stop
  echo "done"
  ;;
  restart)
  echo -n "Restarting bandwidth shaping: "
  restart
  echo "done"
  ;;
  show)
  echo "Bandwidth shaping status for $IF:"
  show
  echo ""
  ;;
  *)
  pwd=$(pwd)
  echo "Usage: tc.bash {start|stop|restart|show}"
  ;;
esac
exit 0

