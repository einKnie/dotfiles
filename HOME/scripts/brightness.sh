#! /bin/bash
# check brightness and increase or decrease by ste

##### BTW
## additionally, birghtness level on the acpi level is set
## in /sys/class/backlight/amdgpu*/brightness
## same path/max_brightness lists the max level (i.e. 100%)

step=0.05
min=0.05
max=1.0

# notification
note_icon=/usr/share/icons/Adwaita/32x32/status/keyboard-brightness-symbolic.symbolic.png

map_brightness_range() {
  b=$(printf "%.2f" $1)
  if [[ $(bc <<< "($b * 100) >= 100") -eq 1 ]]; then
    b=100
  else
    b=$(bc <<< "$b * 100")
  fi
  b=$(printf "%.0f" $b)
  echo $b
}


# function returns a string of the next brightness setting
# call with argument '1' for increase
get_brightness() {
  brightness=""
  for b in $(xrandr --current --verbose | grep -i brightness | sed 's/\(.*\)[a-zA-Z :]//g'); do
    brightness=$b
  done

  if [[ $1 -eq 1 ]]; then
    # inc
    if [[ $(bc <<< "$brightness >= $max") -eq 0 ]]; then
      brightness=$(bc <<< "$brightness + $step")
    fi
  else
    # dec
    if [[ $(bc <<< "$brightness <= $min") -eq 0 ]]; then
      brightness=$(bc <<< "$brightness - $step")
    fi
  fi

  echo $brightness
}

if [ $# -lt 1 ]; then
  echo "no argument given"
  echo "valid arguments: 'up' 'down'"
  exit 1
fi


if [ "$1" == "up" ]; then
  # turn brightness up
  echo up
  bright=$(get_brightness 1)
  echo $bright
elif [ "$1" == "down" ]; then
  # turn brightness down
  echo down
  bright=$(get_brightness)
  echo $bright
else
  echo "invalid argument"
  exit 1
fi


for display in $(xrandr --current --verbose | grep -e '.*[^s]connected' | sed 's/\( connected.*$\)//g'); do
  # set brightness level as calculated above
  xrandr --output $display --brightness $bright
done

# lastly, send notification
b=$(map_brightness_range $bright)
echo "brightness: $b"
dunstify -t 1000 -r 1234 -u normal --icon $note_icon "$b%" -h int:value:$b -h string:hlcolor:"#d0d0d0"
