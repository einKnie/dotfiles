#!/bin/bash
output_file=$HOME/.audioswitch_status
card=0

# get hw id (for some reason this changes from time to time)
card=$(cat /proc/asound/cards | grep DX | sed -r 's/^\s*([0-9]).*/\1/')

if [[ $(amixer -c $card cget iface=MIXER,name='Front Panel Playback Switch') == *"values=on"* ]]; then
  amixer -c $card cset iface=MIXER,name='Front Panel Playback Switch' 0
  echo " " > $output_file
else
  amixer -c $card cset iface=MIXER,name='Front Panel Playback Switch' 1
  echo "" > $output_file
fi

# kill i3status to have it reflect changes immediately
killall -USR1 i3status
