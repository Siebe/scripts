#!/usr/bin/env bash

myipholder=1
ping -qc 1 8.8.8.8 &>/dev/null || myipholder=""
#[ -n "$myipholder" ] && myipholder=$(curl https://ifconfig.io 2>/dev/null)
[ -n "$myipholder" ] && myipholder=$(host myip.opendns.com resolver1.opendns.com 2>/dev/null | grep -P "has (IPv6 )?address" | grep -Po "(((\d+\.)+\d+)|(([a-f0-9]{1,4}:){7}[a-f0-9]{4}))")
export WHATSMYIP="$myipholder"
[ -z "$myipholder" ] && echo "no internet?" && return 1
echo $WHATSMYIP
export WANIP="$WHATSMYIP"