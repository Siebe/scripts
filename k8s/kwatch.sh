#/bin/env bash
if [ -z "$1" ]; then
   ns="--all-namespaces"
else 
   ns="-n $1"
fi

watch -n 1 kubectl get pods $ns
