#!/usr/bin/env bash

newname="$(rofi -dmenu -lines 0 -p 'new name')"
if [ -z "$newname" ] ;then
  exit 0
fi

oldnum="$(i3-msg -t get_workspaces \
  | jq '.[] | select(.focused==true).name' \
  | cut -d"\"" -f2 \
  | sed 's/[^0-9]*$//g')"

if [ -n "$oldnum" ] ;then
  newname="$oldnum $newname"
fi

i3-msg rename workspace to "\"$newname\""
