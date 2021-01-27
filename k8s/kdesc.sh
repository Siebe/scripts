#/usr/bin/env bash

pattern=''
type=''

if [ $# -eq 1 ] ; then
    pattern=$1
fi
if [ $# -eq 2 ] ; then
    pattern=$2
    type=$1
fi

matching=`kubectl get all --all-namespaces | grep -iP "\s+$type.*\/.*$pattern.*\s+"` 

while IFS= read -r match; do
  entry=($match)
  echo --- Description ${entry[1]} \(${entry[0]}\): ---
  kubectl describe -n${entry[0]} ${entry[1]} 
done <<< "$matching"
