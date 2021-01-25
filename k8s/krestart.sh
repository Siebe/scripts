#/bin/env bash

pattern=''
type=''

if [[ $# -eq 1 ]] ; then
    pattern=$1
    type='deployment'
fi
if [[ $# -eq 2 ]] ; then
    pattern=$2
    type=$1
fi

matching=`kubectl get $type --all-namespaces | grep -iP "^([^\s]+)\s+([^\s]*$pattern[^\s]*)\s"` 

while IFS= read -r match; do
  entry=($match)
  echo --- Restarting ${entry[1]} \(${entry[0]}\): ---
  kubectl rollout restart $type -n${entry[0]} ${entry[1]} 
done <<< "$matching"
