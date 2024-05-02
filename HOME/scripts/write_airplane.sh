#!/usr/bin/env bash
outfile="$HOME/.airplane_mode"
max_cycles=20
scriptname="$(basename "$0")"

log_journal() {
  if which systemd-cat &>/dev/null ; then
    echo "$@" | systemd-cat -t "$scriptname"
  else
    echo "$@"
  fi
}

old_state="$(cat /var/lib/systemd/rfkill/pci-0000\:06\:00.0\:wlan)"
log_journal "old rf state: $old_state"

if [ "$old_state" == "0" ]; then
    notify-send "airplane mode"
else
    notify-send "airplane mode off"
fi

new_state="$old_state"
cycles=0

while [ "$old_state" == "$new_state" ]; do
    sleep 0.5
    if [ $cycles -eq $max_cycles ]; then
        log_journal "$max_cycles tries is enough"
        break
    else
        cycles=$((cycles + 1))
        log_journal $cycles
    fi

    new_state="$(cat /var/lib/systemd/rfkill/pci-0000\:06\:00.0\:wlan)"
done

log_journal "rf state: $new_state"

# sleep again to make sure network is up (in most cases at least)
sleep 0.5

# start the weather service
systemctl --user start weather.service&

# update the public ip
$HOME/bin/get_public_ip.sh&

# write file for i3status
if [ "$new_state" == "1" ]; then
    echo "" > $outfile
elif [ "$new_state" == "0" ]; then
    rm $outfile
else
    log_journal "unexpected rf state: $new_state"
    echo "" > $outfile
fi
