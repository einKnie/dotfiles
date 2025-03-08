#!/usr/bin/env bash
# set -x

# Show a 7-day weather forecast as a notification
# requires nerdfont, breeze-dark icon theme, and dunstify
#
# unfortunately, this will stop working some time soon (i think mid 2024)
# the onecall api 2.5 is deprecated, and the 3.0 api requires me to pay.
# (technically not since 1000 calls per day are free, but I don't want to
# give them my payment info for something that i never actually use)
# There is a free 'forecast' api call which will continue to work
# (https://openweathermap.org/forecast5#5days 5-day 3-hour forecast)
# but it is such a pain in the ass to use that i think it is deliberate to force people to pay.
# anyway, when this stops working, i won't fix it.

config=$HOME/.config/weather.conf
api_url="https://api.open-meteo.com/v1/"
test_url="8.8.8.8"
notify_icon=/usr/share/icons/breeze-dark/status/24@3x/state-offline.svg

# declare the icons (nerd font)
declare -A icons_next
icons_next=(
	    [00]="" [01]="" # clear
		[10]="" [11]="" # few clouds
		[20]="󰅟" [21]="󰅟" # clouds
		[30]="" [31]="" # light rain
		[40]="" [41]="" # rain
		[50]="" [51]="" # snow
		[60]="" [61]="" # thunderstorm
		[70]="" [71]="" # fog
		[99]="" #error
	  )

show_config_help() {
	echo "please provide a configuration file at $config"
	echo "with the *only* contents:"
	echo
	echo "latitude of your location"
	echo "longitude of your location"
	echo
	echo "see note at the top of this script for more info"
}

# cleanup on exit
cleanup() {
	ret=$?
	if [ $ret -ne 0 ]; then
		# set error output
		echo " ??" > $output
		if [ $ret -eq 2 ]; then
			show_config_help
		fi
	fi
	exit $ret
}
trap "cleanup" EXIT

# return suitable icon depending on
# weather code and day/night cycle
get_icon() {
	local code=$1
	local day=$2
	local idx=99

	case "$code" in
		0) # clear sky
			idx=00
			;;
		1) # mainly clear
			idx=10
			;;
		2) # partly cloudy
			idx=10
			;;
		3) # overcast
			idx=20
			;;
		45|48) # fog
			idx=70
			;;
		51|52|53) # light, moderate, dense drizzle
			idx=30
			;;
		61) # light rain
			idx=30
			;;
		63|65) # moderate, dense rain
			idx=40
			;;
		71|73|75|77) # snow
			idx=50
			;;
		80|81|82) # rain showers
			idx=30
			;;
		85|86) # snow showers
			idx=50
			;;
		95) # thunderstorm
			idx=60
			;;
		96|99) # thunderstorm with hail
			idx=60
			;;
		*)
			echo "unexpected weather_code: $weather_code"
			;;
	esac

	if [ $day -eq 0 ]; then
		# inc by one for night icon
		((idx++))
	fi

	# check if array subscript exists
	# see https://www.gnu.org/savannah-checkouts/gnu/bash/manual/bash.html#Shell-Parameter-Expansion
	# ${parameter:+word}
	# If parameter is null or unset, nothing is substituted, otherwise the expansion of word is substituted.
	[ "${icons_next[$idx]+exists}" ] || { echo "Invalid icon idx: ${idx}"; exit 1; }

	local icon=${icons_next[$idx]}
	echo "$icon"
}

# ping test_url to see if we're online so we fail early in case we're not
ping -q -c 1 -W 1 $test_url &> /dev/null || { echo "no connection"; exit 1;}

# read the config file for the needed info and generate query
[ -f "$config" ] || [ -s "$config" ] || { echo "no or empty config file found at $config"; exit 1; }
read lat lon <<< $(tr '\n' ' ' <$config)

base_query=$(printf "%sforecast?latitude=%.2f&longitude=%.2f" $api_url $lat $lon)
query=$(printf "%s&daily=weather_code,temperature_2m_max,temperature_2m_min,apparent_temperature_max,apparent_temperature_min&timezone=auto" $base_query)

# fetch data from owm
res=$(curl -s "${api_url}${query}")
#|
#     jq '.daily[]' |
#      sed 's/\"//g')

outstr=""
day=0

while [ $day -lt 7 ]; do

      date=$(date -d @$(echo "res" | jq -r '.daily.time.0') +'%a, %d.%m.' 2>/dev/null)
      tmp_max=$(printf %0.f $(echo "res" | jq ".daily.temperature_2m_max.$day"))
      tmp_min=$(printf %0.f $(echo "res" | jq ".daily.temperature_2m_min.$day"))
      weather_code=$(echo "res" | jq ".daily.weather_code.$day")

      icon=$(get_icon $weather_code 1)

      outstr+="$day $icon\t$tmp_min°C-$tmp_max°C\n"

      ((day++))
done

# display forecast via notification
dunstify -t 0 -r 1236 -u normal --icon=$notify_icon "Forecast" "$outstr"

exit 0

# generate notification text
outstr=""
while read -r line; do

      day=$(date -d @$(awk '{print $1}' <<< $line) +'%a, %d.%m.' 2>/dev/null)
      tmp=$(printf %0.f $(awk '{print $2}' <<< $line))
      icon=$(awk '{print $3}' <<< $line)

      # check if array subscript exists
      # see https://www.gnu.org/savannah-checkouts/gnu/bash/manual/bash.html#Shell-Parameter-Expansion
      # ${parameter:+word}
      # If parameter is null or unset, nothing is substituted, otherwise the expansion of word is substituted.
      [ "${icons_nerd[$icon]+exists}" ] || { echo "Invalid response from owm."; exit 1; }
      i=${icons_nerd[$icon]}

      outstr+="$day ${icons_nerd[$icon]}\t$tmp°C\n"
done <<< $res

# display forecast via notification
dunstify -t 0 -r 1236 -u normal --icon=$notify_icon "Forecast" "$outstr"
