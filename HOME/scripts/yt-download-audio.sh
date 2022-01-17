#!/usr/bin/env bash

# prerequisite: xclip, youtube-dl

DST=$HOME/Music/youtube/

if [ ! -d $DST ]; then
  mkdir -p $DST
fi

RET=$(youtube-dl -x --audio-format mp3 -o "$DST/%(title)s.%(ext)s" $(xclip -o) 2>&1)
if [ $? -ne 0 ]; then
  MSG="Failed to download audio: $RET"
  notify-send -u critical -t 5000 Error "$MSG"
else
  notify-send -u normal -t 5000 Complete "Download complete"
fi
