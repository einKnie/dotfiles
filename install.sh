#!/usr/bin/env bash

# script should go through every dir or file in repo 
# repolace $repo_base with $HOME/.config
# check if a file already exists (deal with that by user config)
# and symlink the repo-file to the repective $HOME file location

# todo:
# - automate the setup - done
# - deal with relative paths! - done
# - maybe even checkout other necessary repos (assorted scripts for example)

debug=0
basedir="$(cd "$(dirname "$0")"; pwd -P)"
ownpath="$(realpath "$0")"

yes_or_no() {
  read -p "$1 [Y/n] " ret
  if [ "$ret" != "N" ] && [ "$ret" != "n" ]; then
    return 0
  else
    return 1
  fi
}

echov()   { [ $verbose -eq 1 ] && echo "$1"; }
echoerr() { cat <<< "error: $@" 1>&2; }

symlink() {
	local file="$1"
	local link="$2"
	local w=""
	local ret=0

	[ $whatif -eq 1 ] && { w="[what-if] "; } || { w=""; }

	if [ -f "$link" ] ; then
		if [ $backup -eq 1 ]; then
			[ $whatif -eq 0 ] && { mv -f "$link" "${link}.bak"; }
			echov "${w}created backup ${link}.bak"
		else
			[ $whatif -eq 0 ] && { rm -f "$link"; }
			echov "${w}removed existing file $link"
		fi
	else
		# create containing directory in case it also does not exist
		[ $whatif -eq 0 ] && { mkdir -p "$(dirname "$link")"; }
		echov "${w}created containing directory $(dirname "$link")"
	fi

	[ $whatif -eq 0 ] && { ln -sf "$file" "$link"; ret=$?; } || { ret=0; }
	if [ $ret -eq 0 ]; then
		echov "${w}created symlink to $file at $link"
	else
		echoerr "${w}failed to create link to $file at $link"
		return 1
	fi

	return 0
}

link_home() {
	local src="$(cd $basedir/HOME; pwd)"
	local dst="$HOME"

	install_config "$src" "$dst"
}

print_config() {

	echov "Source:      $src"
	echov "Destination: $dst"
	echov "Using config:"
	[ $whatif  -eq 1 ] && { echov "  [what if] x"; } || { echov "  [what if] o"; }
	[ $backup  -eq 1 ] && { echov "  [backup]  x"; } || { echov "  [backup]  o"; }
	[ $force   -eq 1 ] && { echov "  [force]   x"; } || { echov "  [force]   o"; }
	[ $verbose -eq 1 ] && { echov "  [verbose] x"; } || { echov "  [verbose] o"; }
	[ $debug   -eq 1 ] && { echov "  [debug]   x"; }
}

install_progs() {
	# this is not generic, works for manjaro
	proglist="i3-wm i3status i3lock dunst picom rofi \
	rxvt-unicode feh git vim ttf-font-awesome zenity"
	if [ $whatif -eq 0 ]; then
		sudo pacman -S $proglist || { echoerr "failed to install programs"; return 1; }
	else
		echov "would install: $proglist"
	fi
}

install_config() {
	local src="$1"
	local dst="$2"
	print_config "$src" "$dst"

	local err=0
	for file in $(find "$src" -type f); do

		linkname="${file/$src/$dst}"
		echov "file:      $file"
		echov "link:      $linkname"

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

setup_ssh() {
	echo "setting up ssh key for github interaction"
	mkdir -p $HOME/.ssh
	ssh-keygen -t ed25519 -C "einKnie@gmx.at" -f $HOME/.ssh/einknie -q || return 1
	ssh-add $HOME/.ssh/einknie || return 1
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

	# setup my own scripts
	#setup_ssh || { echoerr "failed to setup ssh key. aborting."; return 1; }
	
	git clone https://github.com/einKnie/assortedScripts $HOME/scripts/assortedScripts && { 
		ln -sf $HOME/scripts/assortedScripts/reminder.sh $HOME/bin/reminder.sh
	} || { 
		echoerr "failed to clone scripts repo"; ((err++)); 
	}

	git clone https://github.com/einKnie/newworkspace $HOME/scripts/newworkspace || { echoerr "failed to clone newworkspace repo";  ((err++)); }

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
	echo " -s  ... source path"
	echo " -d  ... destination path"
	echo " -b  ... create backups of existing files"
	echo " -n  ... what-if mode"
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
whatif=0
force=0
backup=0
verbose=0
type=0
src=""
dst=""

# get params
while getopts "t:s:d:bnfvh" arg; do
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
	n)
		whatif=1
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
	link_home   || { echoerr "failed to link \$HOME files"; ((err++)); }
	setup_config || { echoerr "failed to adapt ieconfig to current system"; ((err++)); }
fi

[ $err -gt 0 ] && exit 1 || exit 0
