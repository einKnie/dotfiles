#!/usr/bin/env sh

# write bluetooth status symbol to file
#
# This script is called by udev rule /etc/udev/rules.d/50-bluetooth_headset.rules

outfile="$HOME/.bt_status"
scriptname="$(basename "$0")"

headset=""
speaker=""

log_journal() {
  if which systemd-cat &>/dev/null ; then
    echo "$@" | systemd-cat -t "$scriptname"
  else
    echo "$@"
  fi
}

print_help() {
	echo "Simple script to write bluetooth symbols for i3status"
	echo "  usage:  $scriptname -u/-d [-s]"
	echo
	echo "  -a ... bluetooth device added"
	echo "  -r ... bluetooth device removed"
	echo "  -s ... bluetooth device is a speaker"
	echo "         [default: headset]"
	echo
	echo "note: if both -a and -r are provided,"
	echo "the last encountered option is used."
	echo
}

status_old=0
[ -f "$outfile" ] && status_old=1

added=0
speakers=0

while (("$#")); do
    case "$1" in
        -a)
            added=1
            shift 1
            ;;
        -r)
            added=0
            shift 1
            ;;
				-s)
						speakers=1
						shift 1
						;;
        *)
            echo "Error: Unrecoginzed parameter $1"
            print_help
            exit 1
            ;;
    esac
done

if [ $added -eq 1 ]; then
	if [ $speakers -eq 0 ]; then
		echo $headset > "$outfile"
	else
		echo $speaker > "$outfile"
	fi
	[ $status_old -eq 0 ] && log_journal "bluetooth device added"
else
	rm -f "$outfile"
	[ $status_old -eq 1 ] && log_journal "bluetooth device removed"
fi

exit 0
