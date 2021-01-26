#/usr/bin/env bash

pattern=''
type=''

if [[ $# -eq 1 ]] ; then
    pattern=$1
fi
if [[ $# -eq 2 ]] ; then
    pattern=$2
    type=$1
fi

kubectl get all --all-namespaces | grep -iP "\s+$type.*\/.*$pattern.*\s+" 

