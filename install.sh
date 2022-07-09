#!/usr/bin/env bash

# script should go through every dir or file in repo
# replace $repo_base with $HOME/.config
# check if a file already exists (deal with that by user config)
# and symlink the repo-file to the repective $HOME file location

# todo:
# - automate the setup - done
# - deal with relative paths! - done
# - maybe even checkout other necessary repos (assorted scripts for example)

debug=0
basedir="$(cd "$(dirname "$0")"; pwd -P)"
ownpath="$(realpath "$0")"

# programs to be installed
proglist="i3-wm i3status i3lock dunst picom rofi \
	rxvt-unicode feh git vim ttf-font-awesome zenity \
	at dolphin thunderbird htop vnstat"

# logging
echov()   { [ $verbose -eq 1 ] && echo "$1" || return 0; }
echoerr() { cat <<< "error: $@" 1>&2; }

yes_or_no() {
  read -p "$1 [Y/n] " ret
  if [ "$ret" != "N" ] && [ "$ret" != "n" ]; then
    return 0
  else
    return 1
  fi
}

# create a symlink of $1 as link $2
# containing directories are created on the go
symlink() {
	local file="$1"
	local link="$2"
	local ret=0

	if [ -f "$link" ] ; then
		if [ $backup -eq 1 ]; then
			mv -f "$link" "${link}.bak"
			echov "created backup ${link}.bak"
		else
			rm -f "$link"
			echov "removed existing file $link"
		fi
	elif [ ! -d "$(dirname "$link")" ]; then
		# create containing directory in case it also does not exist
		mkdir -p "$(dirname "$link")"
		echov "created containing directory $(dirname "$link")"
	fi

	ln -sf "$file" "$link" && { echov "created symlink to $file at $link"; } || {
		echoerr "failed to create symlink to $file at $link"
		return 1
	}
	return 0
}

link_home() {
	local src="$(cd $basedir/HOME; pwd)"
	local dst="$HOME"

	install_config "$src" "$dst"
}

print_config() {

	echo "Source:      $src"
	echo "Destination: $dst"
	echo "Using config:"
	[ $backup  -eq 1 ] && { echo "  [backup]  x"; } || { echo "  [backup]  o"; }
	[ $force   -eq 1 ] && { echo "  [force]   x"; } || { echo "  [force]   o"; }
	[ $verbose -eq 1 ] && { echo "  [verbose] x"; } || { echo "  [verbose] o"; }
	[ $debug   -eq 1 ] && { echo "  [debug]   x"; }
}

install_progs() {
	# this is not generic, works for manjaro/arch
	sudo pacman -S $proglist || { echoerr "failed to install programs"; return 1; }
}

install_config() {
	local src="$1"
	local dst="$2"
	print_config "$src" "$dst"

	local err=0
	for file in $(find "$src" -type f); do

		linkname="${file/$src/$dst}"

		if [ $force -eq 0 ] && [ -f "$linkname" ]; then
			if ! yes_or_no "Overwrite existing file "$linkname"?"; then
				echov "not overwriting file"
				continue
			fi
		fi

		symlink "$file" "$linkname" || ((err++))
	done

	echov "all done"
	return $err
}

setup_config() {
	local err=0
	# do all the things

	# link files from ~/scripts to ~/bin
	mkdir -p $HOME/bin
	install_config "$basedir/HOME/scripts/" "$HOME/bin/" || { echoerr "failed to link scripts"; ((err++)); }

	# change default shell to bash
	chsh -s /bin/bash || { echoerr "failed to change default shell to bash"; ((err++)); }

	# set correct screen name
	update_i3config || { echoerr "failed to update i3 config file"; ((err++)); }

	# checkout repos
	git clone https://github.com/einKnie/assortedScripts $HOME/scripts/assortedScripts && {
		ln -sf $HOME/scripts/assortedScripts/reminder.sh $HOME/bin/reminder.sh || echoerr "failed to link reminder.sh to \$HOME/bin"
	} || {
		echoerr "failed to clone scripts repo"; ((err++));
	}

	git clone https://github.com/einKnie/newworkspace $HOME/scripts/newworkspace || { echoerr "failed to clone newworkspace repo";  ((err++)); }
	git clone https://github.com/einKnie/ws_mgmt $HOME/scripts/ws_mgmt || { echoerr "failed to clone ws_mgmt repo";  ((err++)); }

	return $err
}

update_i3config() {
  local dp1=""
  local dp2=""
  local wmconfig="$HOME/.config/i3/config"

  # check display setup
  if [ $(xrandr | grep -c " connected") -gt 1 ]; then
    is_multi_monitor=1
  else
    is_multi_monitor=0
  fi

  # get display identifiers
  var=$(xrandr | grep -e '.*[^s]connected' | sed 's/\( connected.*$\)//g' | sed 's/[\n\t ]/ /g')

  dp1=$(echo $var | cut -f1 -d" ")
  dp2=$(echo $var | cut -f2 -d" ")
  echov "primary display: $dp1"
  if [ $is_multi_monitor -eq 1 ]; then
    echov "secondary display: $dp2"
  fi

  if [ $is_multi_monitor -eq 1 ]; then
    # replace primary_display and scondary_display in config file
	mv "$HOME/.config/i3/config_multiscreen" "$wmconfig"
	sed -i.bak -r "s/display_primary \"([A-Za-z0-9\-]*)\"$/display_primary \"$dp1\"/g" "$wmconfig"
	sed -i.bak -r "s/display_secondary \"([A-Za-z0-9\-]*)\"$/display_secondary \"$dp2\"/g" "$wmconfig"
  else
    # only one monitor. edit single_monitor file
	mv "$HOME/.config/i3/config_singlescreen" "$wmconfig"
	sed -i.bak -r "s/display \"([A-Za-z0-9\-]*)\"$/display \"$dp1\"/g" "$wmconfig"
  fi

}

print_help() {
	echo "$(basename "$0") - link config files"
	echo "usage:"
	echo
	echo " -t <type> ... automated mode; possible types are [full, files]*"
	echo " -s  ... source path           (only if no type given)"
	echo " -d  ... destination path      (only if no type given)"
	echo " -b  ... create backups of existing files"
	echo " -f  ... force; don't ask before overriding existing files"
	echo " -v  ... verbose; print info messages"
	echo " -h  ... print this help"
	echo
	echo "* types:"
	echo "  full - install all necessary programs and available files"
	echo "  files - install only files, not programs"
}

###############################################################################

#defaults
force=0
backup=0
verbose=0
type=0
src=""
dst=""

# get params
while getopts "t:s:d:bfvh" arg; do
case $arg in
	t)
		case $OPTARG in
			full)
				type=1
				;;
			files)
				type=2
				;;
			*)
				echoerr "invalid type argument given"
				type=0
				;;
			esac
		;;
	s)
		if [ -d "$OPTARG" ]; then
			src="$(cd "$OPTARG" && pwd)"
		else
			echoerr "given source is not a directory"
			exit 1
		fi
		;;
	d)
		if [ -d "$OPTARG" ]; then
			dst="$(cd "$OPTARG" && pwd)"
		else
			echoerr "given destination is not a directory"
			exit 1
		fi
		;;
	b)
		backup=1
		;;
	f)
		force=1
		;;
	v)
		verbose=1
		;;
	h)
		print_help
		exit 0
		;;
esac
done

# temporary debug stuff
if [ $debug -eq 1 ]; then
	verbose=1
	backup=1
fi

echo "type: $type"
# quick sanity check
err=0
if [ $type -eq 0 ]; then
	[ -n "$src" ] || { echoerr "source path not set"; ((err++)); }
	[ -n "$dst" ] || { echoerr "destination path not set"; ((err++)); }
fi
[ $err -gt 0 ] && { print_help; exit 1; }

err=0
if [ $type -eq 0 ]; then
	# just a regular specific file linking
	# we have src and dst set
	install_config "$src" "$dst" || { echoerr "failed to link files"; ((err++)); }
else
	if [ $type -eq 1 ]; then
		# install programs
		install_progs || { echoerr "failed to install programs"; ((err++)); }
	fi

	# link all files
	link_home    || { echoerr "failed to link \$HOME files"; ((err++)); }
	setup_config || { echoerr "failed to adapt ieconfig to current system"; ((err++)); }
fi

[ $err -gt 0 ] && exit 1 || exit 0
