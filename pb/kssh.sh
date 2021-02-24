#!/usr/bin/env bash

if [ -z "$WHATSMYIP" ] || [ "$WHATSMYIP" != "$KANTOORIP"]; then
  ssh -o ProxyCommand="ssh -W %h:%p siebe@${KANTOORIP}" $@
else
  ssh $@
fi
