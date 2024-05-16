#!/bin/bash

CURRENT_KEYMAP_PATH=~/.config/keymap_current

CURRENT_KEYMAP=$(cat "$CURRENT_KEYMAP_PATH" | grep "sticky")

if [[ $CURRENT_KEYMAP ]]; then
   # echo "{\"text\": \"🗝️\", \"class\": \"active\"}"
   # echo "{\"text\": \"\", \"class\": \"active\"}"
   # echo "{\"text\": \"l\", \"class\": \"active\"}"
   echo "{\"text\": \"🔗\", \"class\": \"active\"}"
else
   # echo "{\"text\": \"🔒\", \"class\": \"inactive\"}"
   # echo "{\"text\": \"\", \"class\": \"inactive\"}"
   # echo "{\"text\": \"L\", \"class\": \"inactive\"}"
   echo "{\"text\": \"⛓️\", \"class\": \"inactive\"}"
fi
