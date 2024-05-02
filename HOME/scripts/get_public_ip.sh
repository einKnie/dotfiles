#!/usr/bin/env bash

# script shall fetch public ip and write to a file
# if no internet connection, file should be set empty
#set -x
ipfile="$HOME/.publicip"

# write current external ip to file
ip="$(dig +short myip.dnsomatic.com 2>/dev/null)"
if [ "$?" -ne 0 ]; then
	echo "error: could not fetch public ip: $?"
  rm "$ipfile"
else
	echo "public ip: $ip"
  echo "$ip" > "$ipfile"
fi


