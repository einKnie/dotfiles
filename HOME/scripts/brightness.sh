#! /bin/bash
# check brightness and increase or decrease by ste

##### BTW
## additionally, birghtness level on the acpi level is set
## in /sys/class/backlight/amdgpu*/brightness
## same path/max_brightness lists the max level (i.e. 100%)

step=0.05
min=0.05
max=1.0

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
