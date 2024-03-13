#!/usr/bin/env bash

# store currently active wifi connection to a file
# this is used by 70-wifi-wired-switch.sh to enable
# the last known wifi connection if required
#set -x

# sorry, i'm lazy
myname="60-wifi-last-connection"

# set to device to manage
# check device name with
# nmcli dev | grep wifi | awk -F' ' '{printf $1}'
device="wlan0"
last_con_file="/home/lila/.last_wifi"

trim() {
	local var="$*"
	# remove leading whitespace
	var="${var#"${var%%[![:space:]]*}"}"
	# remove trailing whitespace
	var="${var%"${var##*[![:space:]]}"}"
	printf '%s' "$var"
}

get_wifi_connection(){
	local conn_id="$(nmcli dev | grep "$device" | grep "connected" | awk -F'  +' '{print $(NF)}')"
	[ -z "$conn_id" ] || [ "$conn_id" != "--" ] || { echo "" ; return 1; }
	echo "$conn_id"
}

store_connection() {
	local conn_id="$(get_wifi_connection)"
	[ -z "$conn_id" ] || { return 1; }
	echo "$conn_id" > "$last_con_file"
}

[ "$1" != "$device" ] && exit 0
#echo "$myname called with:  $@"

case "$2" in
	up)
		store_connection && {
			echo "$myname stored active wifi connection"
		} || {
			echo "$myname: failed to get active connection"
		}
		;;
	*)
		;;
esac

