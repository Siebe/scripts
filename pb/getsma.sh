#!/usr/bin/env bash

hostfile=$1
if [ -z "$1" ];
  then echo "enter a hostfile";
  exit 1;
fi
cd ~/Projects/radiomanager-ansible
ip=`cat $hostfile | grep -P "\d+\.\d+\.\d+\.\d+\s+lastpart_ip\=.+hostname=.+-webworker-01"| grep -Po "^\d+\.\d+\.\d+\.\d+"`
if [ -z "$ip" ];
  then echo "not found!";
  exit 1;
fi
ssh -J siebe@kantoor.pluxbox.nl root@$ip 'php /var/www/radiomanager/artisan sma:password'
