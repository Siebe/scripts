#!/usr/bin/env bash

pattern=''

if [ $# -eq 1 ] ; then
    pattern=$1
    nsflag="--all-namespaces"
fi
if [ $# -eq 2 ] ; then
    pattern=$2
    namespace=$1
    nsflag="-n '{namespace}'"
fi

matching=`kubectl get deployment ${nsflag} | grep -ioP "^([^\s]+)\s+([^\s]*${pattern}[^\s]*)\s"` 

while IFS= read -r match; do
  entry=("$match")
  echo --- Restarting ${entry[1]} \(${entry[0]}\): ---
  kubectl rollout restart deployment -n${entry[0]} ${entry[1]} 
done <<< "$matching"
