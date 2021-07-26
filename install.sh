#!/usr/bin/env bash

# script should go through every dir or file in repo 
# repolace $repo_base with $HOME/.config
# check if a file already exists (deal with that by user config)
# and symlink the repo-file to the repective $HOME file location

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

echodbg() { [ $debug -eq 1 ] && echo "dbg: $1"; }
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

print_help() {
	echo "$(basename "$0") - usage"
	echo
	echo "create symlinks for all files in this directory"
	echo "at their relative path in $HOME/"
	echo
	echo " -d  ... destination path [default: $HOME/ ]"
	echo " -b  ... create backups of existing files"
	echo " -n  ... what-if mode"
	echo " -f  ... force; don't ask before overriding existing files"
	echo " -v  ... verbose; print info messages"
	echo " -h  ... print this help"
	echo
}


#defaults
whatif=0
force=0
backup=0
verbose=0
dst="$HOME/.config"

# get params
while getopts "d:bnfvh" arg; do
case $arg in
	d)
		if [ -d "$OPTARG" ]; then
			dst="$OPTARG"
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

# show configuration
echov "destination: $dst"
echov "Using config:"
[ $whatif -eq 1  ] && { echov "  [what if] x"; } || { echov "  [what if] o"; }
[ $backup -eq 1  ] && { echov "  [backup]  x"; } || { echov "  [backup]  o"; }
[ $force -eq 1   ] && { echov "  [force]   x"; } || { echov "  [force]   o"; }
[ $verbose -eq 1 ] && { echov "  [verbose] x"; } || { echov "  [verbose] o"; }
[ $debug -eq 1   ] && { echov "  [debug]   x"; }

echodbg "repo path: $basedir"
echodbg "dst path:  $dst"

err=0

for file in $(find "$basedir" -type f); do
	[ "$file" == "$ownpath" ] && continue

	linkname="${file/$basedir/$dst}"
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
[ $err -gt 0 ] && exit 1 || exit 0