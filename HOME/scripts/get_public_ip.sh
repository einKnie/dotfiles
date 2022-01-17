#!/usr/bin/env bash

# script shall fetch public ip and write to a file
# if no internet connection, file should be set empty
set +x
ipfile="$HOME/.publicip"

# write current external ip to file
ip="$(dig +short myip.opendns.com @resolver1.opendns.com)"
if [ "$?" -ne 0 ]; then
  echo "" > "$ipfile"
else
  echo "/ $ip" >"$ipfile"
fi


