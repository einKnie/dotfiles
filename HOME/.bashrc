# .bashrc

# Source global definitions
if [ -f /etc/bashrc ]; then
	. /etc/bashrc
fi

# source user-specific config files
user_cfg_dir="${HOME}/.config/bashrc"
if [ -d "$user_cfg_dir" ] ; then
	for cfg in ls ${user_cfg_dir}/bashrc_* ; do
		. $cfg
	done
fi

# backup PS1
export PS1="\u > "

######################################################
# everything after this is automatically added       #
# by installers et al                                #
######################################################

