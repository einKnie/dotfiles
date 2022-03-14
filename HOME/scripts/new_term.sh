#!/usr/bin/env bash

# open a new terminal. if the currently focused window is also a terminal,
# set pwd of the new one to the current one's.

is_urxvt() {
    # check if window of given windowId is urxvt
    xprop -id $1
    if xprop -id $1 | grep WM_CLASS | grep -i urxvt ; then
        return 0
    else
        return 1
    fi
}

# get window id of currently focused window
winId="$(xdpyinfo | grep focus | sed -r 's/^.*(0x[0-9]+)(,|\s).*$/\1/g')"
pid="$(xprop -id $winId | grep PID | cut -d " " -f3)"

if is_urxvt $winId ; then

    # get pid of last child that has a cwd
    found=0
    last=""
    tree="$(pstree -lpA $pid)"

    while [ $found -eq 0 ] ;do
        last="$(echo "$tree" | sed -re 's/^.*---\w+\(([0-9]+)\)(-\+-.*)?$/\1/g')"
        if [[ "$last" == "$tree" ]]; then
            # abort when no more results found
            break
        fi
        tree=${tree%---*}

        if [ -e "/proc/$last/cwd" ]; then
            found=1
        fi
    done

    if [ $found -eq 1 ] ;then
        realpid=$((last))

        if [ -e "/proc/$realpid/cwd" ] ;then
            urxvt -cd "$(readlink "/proc/$realpid/cwd")" &
            exit 0
        fi
    fi
fi

urxvt &
