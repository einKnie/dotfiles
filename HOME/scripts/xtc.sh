#!/usr/bin/env bash

# script shall toggle screen banking
# i.e. get current screen blanking set and apply the opposite
#set -x

scriptname="$(basename "$0")"
log_journal() {
  if which systemd-cat &>/dev/null ; then
    echo "$@" | systemd-cat -t "$scriptname"
  else
    echo "$@"
  fi
}

blank_is_active() {
  case `expr match "$(xset q)" '.*DPMS is \([ED][a-z]*\)'` in
    Enabled)
      return 0
      ;;
    Disabled)
      return 1
      ;;
    *)
      log_journal "error: unexpected output of 'xset q'"
      exit 1
      ;;
    esac
}

set_blank() {
  if [ $1 -eq 0 ]; then
    # blank off
    log_journal "disabling screen blanking"
    xset s off -dpms
  else
    # blank on
    log_journal "enabling screen blanking"
    xset s on +dpms
  fi
}

if blank_is_active ; then
  set_blank 0
else
  set_blank 1
fi
