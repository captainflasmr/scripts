#! /bin/bash

swaymsg -t get_tree | jq '.. | (.nodes? // empty)[] | select(.nodes==[]) | select(.type=="con") | .app_id?'
