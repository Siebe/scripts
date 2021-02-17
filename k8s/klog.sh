#!/usr/bin/env bash

entry=(`kubectl get pods --all-namespaces | grep $1 | head -n1`)
echo --- Logs from ${entry[1]} \(${entry[0]}\): ---
kubectl logs -f -n${entry[0]} ${entry[1]} --all-containers
