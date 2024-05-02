#!/usr/bin/env bash

# Show a 7-day weather forecast as a notification
# requires nerdfont, breeze-dark icon theme, and dunstify
#set -x

config=$HOME/.config/weather.conf
api_url="https://api.openweathermap.org/data/2.5/"
test_url="8.8.8.8"
notify_icon=/usr/share/icons/breeze-dark/status/24@3x/state-offline.svg

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

# ping test_url to see if we're online so we fail early in case we're not
ping -q -c 1 -W 1 $test_url &> /dev/null || { echo "no connection"; exit 1;}

# read the config file for the needed info and generate query
[ -f "$config" ] || [ -s "$config" ] || { echo "no or empty config file found at $config"; exit 1; }
read lat lon apikey <<< $(tr '\n' ' ' <$config)
query=$(printf "onecall?lat=%.2f&lon=%.2f&appid=%s&units=metric" $lat $lon $apikey)

# fetch data from owm
res=$(curl -s "${api_url}${query}" |
      jq '.daily[] | "\(.dt) \(.temp.day) \(.weather[].icon)"' |
      sed 's/\"//g')

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
