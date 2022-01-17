#!/usr/bin/env bash

# Show a 7-day weather forecast as a notification

CONFIG=$HOME/.config/weather.conf
LAT=48.220999
LON=16.362096

read a b c <<< $(tr '\n' ' ' <$CONFIG)
 
res=$(curl -s "https://api.openweathermap.org/data/2.5/onecall?lat=$LAT&lon=$LON&appid=$b&units=$c" | jq '.daily[] | "\(.dt) \(.temp.day) \(.weather[].icon)"')

# create &| empty tempfile to store output string
tmpfile=/tmp/forecast
echo "" > $tmpfile

OLDIFS=$IFS
IFS='"'
for line in $res; do

  dt=$(date -d @$(awk '{print $1}' <<< $line) +'%a, %d.%m.' 2>/dev/null)
  tmp=$(printf %0.f $(awk '{print $2}' <<< $line))
  e=$(awk '{print $3}' <<< $line)

  # need this hack b/c for some reason i cannot detect if line is empty -.-
  if [ "$dt" == "" ]; then
    continue
  fi
  
  i=""
  if [[ $e == 01d ]]; then
        i="" #clear day
  elif [[ $e == 01n ]]; then
        i="" #clear night
  elif [[ $e == 02d ]]; then
        i="" #few clouds day
  elif [[ $e == 02n ]]; then
        i="" #few clouds night
  elif [[ $e == 03* || $e == 04*  ]]; then
        i="" #scattered/broken clouds day/night
  elif [[ $e == 09* ]]; then
        i="" #shower rain day/night
  elif [[ $e == 10d ]]; then
        i="" #rain day
  elif [[ $e == 10n ]]; then
        i="" #rain night
  elif [[ $e == "10d 11d" ]]; then
        i="" #thunderstorm day
  elif [[ $e == "10n 11n" ]]; then
        i="" #thunderstorm night
  elif [[ $e == 11* ]]; then
        i="" #thunderstorm generic
  elif [[ $e == 13* ]]; then
        i="" #snow day/night
  elif [[ $e == 50* ]]; then
        i="" #fog day/night
  fi

  echo -e "$dt $i\t$tmp°C" >> $tmpfile
done
IFS=$OLDIFS

notify-send -t 0 -u low "Forecast" "$(cat $tmpfile)"

