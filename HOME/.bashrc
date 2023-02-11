# .bashrc

# Source global definitions
if [ -f /etc/bashrc ]; then
	. /etc/bashrc
fi

# User specific environment
if ! [[ "$PATH" =~ "$HOME/.local/bin:$HOME/bin:" ]]
then
    PATH="$HOME/.local/bin:$HOME/bin:$PATH"
fi
export PATH

# Uncomment the following line if you don't like systemctl's auto-paging feature:
# export SYSTEMD_PAGER=

# User specific aliases and functions

export EDITOR=vim

#export PATH=$PATH:~/bin
. $HOME/.config/gitprompt.sh
alias ls='ls --color=auto'
alias ll='ls -la --color=auto'
alias lol='fortune | lolcat'
alias tig='tig --all'
alias gitdiff='git difftool --tool=meld -d'
alias bat='bat --theme="ansi-dark"'

# convenience function for vpn interaction
vpn() {
    sudo systemctl $1 openvpn-client@client
}

# convenience function to set backlight
backlight() {
    echo "$1" | sudo tee /sys/class/backlight/amdgpu_bl1/brightness
}

# list child directories sorted by size
dus() {
  du -d1 -h "$1" | sort -hr
}

# start bash auditing session
audit() {
	if [ "$1" == "stop" ]; then
		source NOAUDIT
	else
		source AUDIT
	fi
}

# use custom stylesheet for dolphin to enable dark background
alias dolphin='dolphin -stylesheet $HOME/.config/qt5ct/qss/dolphin-background.qss'

# set color scheme for other-exec dirs
LS_COLORS="$LS_COLORS:ow=34;100"
export LS_COLORS

# bash promt
# the PS1 works but calls printf every time
# (i tried to implement a bash command logger and was faced
# with an extra printf command being logged for every command i issued)
#export PS1='\[\e[32m\][\u \w$(__git_ps1 " (%s)")]\[\e[m\] '

# __git_ps1 sets PS1; args: line before gitinfo (basically PS1), line after (fmt end), formatstr for gitinfo
export PROMPT_COMMAND='__git_ps1 "\\[\e[32m\]\u@\h \w" "\[\e[m\] " "(%s) "'
# backup PS1
export PS1="\u > "

#eval "$(starship init bash)"

# support mouse scrolling in less and man pages
export LESS="--mouse -R"


