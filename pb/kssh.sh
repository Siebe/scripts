#!/usr/bin/env bash

if [ -z "$@" ]; then
  ssh siebe@${KANTOORIP}
  exit 0
fi

if [ -z "$WHATSMYIP" ] || [ "$WHATSMYIP" != "$KANTOORIP" ]; then
  ssh -o StrictHostKeyChecking=no -o ProxyCommand="ssh -W %h:%p siebe@${KANTOORIP}" $@
  exit 0
fi

ssh $@