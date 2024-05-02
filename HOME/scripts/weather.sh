#!/bin/bash
#set -x

############################################################
#                                                          #
# Fetch the current weather, format it into '$icon $temp', #
# and write to a file.                                     #
#                                                          #
# Provide a config file at the path set in $config         #
# with the *only* content (each value in a new line):      #
# ${latitude of location}                                  #
# ${longitude of location}                                 #
# ${api_key}                                               #
#                                                          #
# where lat and lon are the coordinates of the location    #
# you want to get the weather for, and the api key         #
# can be generated for free (but with account) at          #
# https://openweathermap.org/price#weather                 #
# (you want the Free plan (Current Weather and Forecast))  #
#                                                          #
############################################################

# variables
output=$HOME/.weather
config=$HOME/.config/weather.conf
api_url="https://api.openweathermap.org/data/2.5/"
test_url="8.8.8.8"

# declare the icons (fontawesome)
declare -A icons_awesome
icons_awesome=(
	    [01d]="" [01n]="" # clear
		[02d]="" [02n]="" # few clouds
		[03d]="" [03n]="" # clouds
		[04d]="" [04n]="" # clouds
		[09d]="" [09n]="" # light rain
		[10d]="" [10n]="" # rain
		[13d]="" [13n]="" # snow
		[11d]="" [11n]="" # thunderstorm
		[50d]="" [50n]="" # fog
	  )

# declare the icons (nerd font)
declare -A icons_nerd
icons_nerd=(
	    [01d]="" [01n]="" # clear
		[02d]="" [02n]="" # few clouds
		[03d]="󰅟" [03n]="󰅟" # clouds
		[04d]="󰅟" [04n]="󰅟" # clouds
		[09d]="" [09n]="" # light rain
		[10d]="" [10n]="" # rain
		[13d]="" [13n]="" # snow
		[11d]="" [11n]="" # thunderstorm
		[50d]="" [50n]="" # fog
	  )

# cleanup on exit
cleanup() {
	ret=$?
	if [ $ret -ne 0 ]; then
		# set error output
		echo " ??" > $output
	fi
	exit $ret
}
trap "cleanup" EXIT

# ping test_url to see if we're online so we fail early in case we're not
ping -q -c 1 -W 1 $test_url &> /dev/null || { echo "no connection"; exit 1;}

# read the config file for the needed info and generate query
# check if file exists and is not empty (no need to overdo it, there's enough error checking later on)
[ -f "$config" ] || [ -s "$config" ] || { echo "no or empty config file found at $config"; exit 1; }
read lat lon apikey <<< $(tr '\n' ' ' <$config)
query=$(printf "weather?lat=%.2f&lon=%.2f&appid=%s&units=metric" $lat $lon $apikey)

# get current weather info from OWM
# use jq to strip it down to main temp and the icon id, then strip linebreaks
read temp icon <<< $(curl -s "${api_url}${query}" |
	jq -r '.main.temp, .weather[].icon' |
	tr '\n' ' ')

# check if array subscript exists
# see https://www.gnu.org/savannah-checkouts/gnu/bash/manual/bash.html#Shell-Parameter-Expansion
# ${parameter:+word}
# If parameter is null or unset, nothing is substituted, otherwise the expansion of word is substituted.
[ "${icons_nerd[$icon]+exists}" ] || { echo "Invalid response from owm."; exit 1; }

# fetch the icon
i=${icons_nerd[$icon]}

# force into a two digit whoole number so the width of the
# output does not change whether it's ' 5°' or '25°'
t=$(printf %2.f $temp)

# finally print to file
echo "$i $t°" > $output
