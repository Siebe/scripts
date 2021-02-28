#!/usr/bin/env bash

myipholder=1
ping -qc 1 8.8.8.8 &>/dev/null || myipholder=""
#[ -n "$myipholder" ] && myipholder=$(curl https://ifconfig.io 2>/dev/null)
[ -n "$myipholder" ] && myipholder=$(host myip.opendns.com resolver1.opendns.com 2>/dev/null | grep "has address" | grep -Po "(\d+\.)+\d+")
export WHATSMYIP="$myipholder"
[ -z "$myipholder" ] && echo "no internet?" && exit 1
echo $WHATSMYIP
export WANIP="$WHATSMYIP"