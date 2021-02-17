#!/usr/bin/env bash

ssh -o ProxyCommand="ssh -W %h:%p siebe@kantoor.pluxbox.nl" $@
