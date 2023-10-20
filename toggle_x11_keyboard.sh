#!/bin/bash

if ! pgrep "^onboard$" >/dev/null; then
   onboard &
else
   killall onboard
fi
