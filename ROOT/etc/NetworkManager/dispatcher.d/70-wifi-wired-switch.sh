#!/usr/bin/env bash

# manage exclusive wifi/wired connection
#set -x

# sorry, i'm lazy
myname="70-wifi-wired-switch"

# set to device to manage
# check device name with
# nmcli dev | grep ethernet | awk -F' ' '{printf $1}'
device="enp5s0"
last_con_file="/home/lila/.last_wifi"

trim() {
	local var="$*"
	# remove leading whitespace
	var="${var#"${var%%[![:space:]]*}"}"
	# remove trailing whitespace
	var="${var%"${var##*[![:space:]]}"}"
	printf '%s' "$var"
}

get_last_connection() {
	local conn_id="$(cat "$last_con_file")"
	echo "$conn_id"
}

#echo "$myname called with $@"

[ "$1" != "$device" ] && exit 0
id="$(trim "$(get_last_connection)")"

case "$2" in
	up)
		nmcli con down "$id" && {
			echo "$myname disabled wifi connection"
		} || {
			echo "$myname failed to disable wifi connection"
		}
		;;
	down)
		nmcli con up "$id" && {
			echo "$myname enabled wifi connection"
		} || {
			echo "$myname failed to enable wifi connection"
		}
		;;
	*)
		;;
esac

