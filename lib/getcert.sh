#!/usr/bin/env bash

hostname=$1
timeout 5 openssl s_client -connect ${hostname}:443 -servername ${hostname} -showcerts 2>/dev/null | openssl x509 -noout -text