#!/bin/bash
# set -x

############################################################
#                                                          #
# Fetch the current weather, or forecast.                  #
# Current weather is formatted into '$icon $temp',         #
# and written to a defined output file.                    #
#                                                          #
# The forecast is presented as a notification.             #
#                                                          #
#                                                          #
# Provide a config file at the path set in $config         #
# with the *only* content (each value in a new line):      #
# ${latitude of location}     (e.g 48.2359)                #
# ${longitude of location}                                 #
#                                                          #
# This script uses https://open-meteo.com                  #
#                                                          #
############################################################

# declare the icons (nerd font)
declare -A icons_next
icons_next=(
	  [0]=""  [1]=""  # clear
		[10]="" [11]="" # few clouds
		[20]="󰅟" [21]="󰅟" # clouds
		[30]="" [31]="" # light rain
		[40]="" [41]="" # rain
		[50]="" [51]="" # snow
		[60]="" [61]="" # thunderstorm
		[70]="" [71]="" # fog
		[95]="" [96]="" # error
	  )

show_config_help() {
	echo "Provide a configuration file at $config"
	echo "with the *only* contents:"
	echo
	echo "latitude of your location (e.g 48.2359)"
	echo "longitude of your location"
	echo
}

show_help() {
	echo "Weather Service v1"
	echo
	echo "Usage:"
	echo "  -c | --current   |  write current weather to file"
	echo "  -o | --output    |  output file for current weather"
	echo "     |             |    [ default: $HOME/.weather ]"
	echo " --- | ----------- | ------------------------------------"
	echo "  -f | --forecast  |  show forecast notification"
	echo "  -d | --days      |  forecast days (1,3,7,14)"
	echo "     |             |    [ default: 7 ]"
	echo " --- | ----------- | ------------------------------------"
	echo "  -h | --help      |  show help"
	echo
}

# cleanup on exit
cleanup() {
	ret=$?
	if [ $ret -ne 0 ]; then
		# set error output
		echo " ??" > $output
		case "$ret" in
			1) show_help ;;
			2) show_config_help ;;
			*) ;;
		esac
	fi
	exit $ret
}

# exit without cleanup
early_exit() {
	ret=$?
	case "$ret" in
		0) ;;
		1) show_help ;;
		2) show_config_help ;;
		*) ;;
	esac
	exit $ret
}

# return suitable icon depending on
# weather code and day/night cycle
get_icon() {
	local code=$1
	local day=$2
	local idx=95

	case "$code" in
		0) # clear sky
			idx=0 ;;
		1) # mainly clear
			idx=10 ;;
		2) # partly cloudy
			idx=10 ;;
		3) # overcast
			idx=20 ;;
		45|48) # fog
			idx=70 ;;
		51|52|53) # light, moderate, dense drizzle
			idx=30 ;;
		61) # light rain
			idx=30 ;;
		63|65) # moderate, dense rain
			idx=40 ;;
		71|73|75|77) # snow
			idx=50 ;;
		80|81|82) # rain showers
			idx=30 ;;
		85|86) # snow showers
			idx=50 ;;
		95) # thunderstorm
			idx=60 ;;
		96|99) # thunderstorm with hail
			idx=60 ;;
		*) # unknown
			;;
	esac

	if [ "$day" == "0" ]; then
		# inc by one for night icon
		((idx++))
	fi

	# check if array subscript exists
	# see https://www.gnu.org/savannah-checkouts/gnu/bash/manual/bash.html#Shell-Parameter-Expansion
	# ${parameter:+word}
	# If parameter is null or unset, nothing is substituted, otherwise the expansion of word is substituted.
	#[ "${icons_next[$idx]+exists}" ] || { echo "Invalid icon idx: ${idx}"; exit 1; }

	local icon=${icons_next[$idx]}
	echo "$icon"
}

get_feelslike() {
	local t_min="$1"
	local t_max="$2"
	local ta_min="$3"
	local ta_max="$4"

	local feels=""
	if [ $ta_max -lt $t_max ]; then
		if [ $(($t_max - $ta_max)) -ge 4 ]; then
			feels=""
		else
			feels=""
		fi
	elif [ $ta_min -gt $t_min ]; then
		if [ $(($ta_min - $t_min)) -ge 4 ]; then
			feels=""
		else
			feels=""
		fi
	fi
	echo "$feels"
}

#                            #
#      WEATHER STATION       #
#                            #

# variables
config=$HOME/.config/weather.conf
api_url="https://api.open-meteo.com/v1/"
test_url="8.8.8.8"
notify_icon=/usr/share/icons/breeze-dark/status/24@3x/state-offline.svg
rain_warning="󱔂"
wind_warning="󱗺"

# configuration
output=$HOME/.weather
current=1 # backwards compatibility, do current per default
forecast=0
forecast_days=7
verbose=0

trap "early_exit" EXIT

# parse parameters
while [[ $# -gt 0 ]]; do
	case $1 in
		-f|--forecast)
			forecast=1
			shift
			;;
		-c|--current)
			current=1
			shift
			;;
		-o|--output)
			output="$2"
			shift; shift
			;;
		-d|--days)
			forecast_days="$2"
			if ! [[ $forecast_days =~ ^1|3|7|14$ ]]; then
				echo "invalid number of forecast days: $forecast_days"
				exit 1
			fi
			shift; shift
			;;
		-v)
			verbose=1
			shift
			;;
		-h|--help)
			show_help
			exit 0
			;;
		*)
			echo "Unknown option $1"
			exit 1
			;;
	esac
done

# check parameters
[ $((current+forecast)) -eq 0 ] && exit 0 #nothing to do

# check config
# check if file exists and is not empty
[ -f "$config" ] || [ -s "$config" ] || { echo "no or empty config file found at $config"; exit 2; }
read lat lon <<< $(tr '\n' ' ' <$config)

[[ $lat =~ ^[0-9]+(\.[0-9]+)?$ ]] || { echo "invalid config file contents: $lat"; exit 2; }
[[ $lon =~ ^[0-9]+(\.[0-9]+)?$ ]] || { echo "invalid config file contents: $lon"; exit 2; }

# set exit trap
trap "cleanup" EXIT

# ping test_url to see if we're online so we fail early in case we're not
ping -q -c 1 -W 1 $test_url &> /dev/null || { echo "no connection"; exit 3;}


base_query=$(printf "%sforecast?latitude=%.4f&longitude=%.4f" $api_url $lat $lon)

if [ $current -eq 1 ]; then
	query=$(printf "%s&current=temperature_2m,apparent_temperature,is_day,weather_code&timezone=auto" $base_query)

	# get current weather info
	# use jq to strip it down to main temp and the icon and day info, then strip linebreaks
	read temp temp_a weather_code is_day <<< $(curl -s "${query}" |
		jq -r '.current.temperature_2m, .current.apparent_temperature, .current.weather_code, .current.is_day' |
		tr '\n' ' ')

	# get icon for weather
	i=$(get_icon $weather_code $is_day)

	# force temperature into a two digit whole number so the width of the
	# output does not change whether it's ' 5°' or '25°'
	t=$(printf %2.f $temp)
	ta=$(printf %2.f $temp_a)

	# finally print to file
	if [ "$t" == "$ta" ]; then
		echo "$i $t°" > $output
	else
		echo "$i $t°($ta°)" > $output
	fi
fi

if [ $forecast -eq 1 ]; then
	query=$(printf "%s&daily=weather_code,temperature_2m_max,temperature_2m_min,apparent_temperature_max,apparent_temperature_min,precipitation_sum,precipitation_hours,wind_speed_10m_max&timezone=auto&forecast_days=%d" $base_query, $forecast_days)

	res=$(curl -s "${query}" | jq -r ".daily")
	outstr=""
	day=0

	while [ $day -lt $forecast_days ]; do

		date=$(date -d $(echo "$res" | jq -r ".time[$day]") +'%a, %d.%m' 2>/dev/null)

		tmp_max=$(printf %0.f $(echo "$res"  | jq ".temperature_2m_max[$day]"))
		tmp_min=$(printf %0.f $(echo "$res"  | jq ".temperature_2m_min[$day]"))
		tmpa_max=$(printf %0.f $(echo "$res" | jq ".apparent_temperature_max[$day]"))
		tmpa_min=$(printf %0.f $(echo "$res" | jq ".apparent_temperature_min[$day]"))
		rain_h=$(printf %0.f $(echo "$res"   | jq ".precipitation_hours[$day]"))
		rain=$(printf %0.f $(echo "$res"     | jq ".precipitation_sum[$day]"))
		wind=$(printf %0.f $(echo "$res"     | jq ".wind_speed_10m_max[$day]"))
		weather_code=$(echo "$res"           | jq ".weather_code[$day]")
		icon=$(get_icon $weather_code 1)

		# add weather warnings
		r=" "
		w=" "
		if [ $rain_h -ge 8 ] || [ $rain -ge 10 ]; then #todo: get canonical thresholds
			r="$rain_warning"
		fi
		if [ $wind -ge 15 ]; then #todo: get canonical threshold
			w="$wind_warning"
		fi

		warnings="   "
		if [ "$r$w" != "  " ]; then
			warnings="$r $w"
		fi

		feels=$(get_feelslike "$tmp_min" "$tmp_max" "$tmpa_min" "$tmpa_max")

		if [ $verbose -eq 0 ]; then
			# print main weather info (icon, min-max, apparent higher or lower)
			outstr+=$(printf "%s %s  %2d°-%d°C %s   %s" "$date" "$icon" "$tmp_min" "$tmp_max" "$feels" "$warnings")
		else
			# print extended weather info (icon, min-max, apparent min-max)
			outstr+=$(printf "%s %s\n %s    %2d°-%d°C (%d°-%d°) %s" "$date" "$warnings" "$icon" "$tmp_min" "$tmp_max" "$tmpa_min" "$tmpa_max" "$feels")
		fi

		outstr+="\n"

		((day++))
	done

	# display forecast via notification
	notify-send -t 0 -r 1236 -u normal --icon=$notify_icon "Forecast" "$outstr"
fi
