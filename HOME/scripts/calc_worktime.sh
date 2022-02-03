#!/usr/bin/env bash

# given a .locktime file, calculate unlocked time per unlock-lock pair.

locktime_path="$HOME/scripts/test_locktimes"
timesheet_path="$HOME/Documents/timesheet"

# file header
timesheet_header="LOGIN               LOGOUT              TIME DELTA"
		         #22-02-04 08:59:47   22-02-04 18:30:43   [ 9:30 ]
timesheet_line="--------------------------------------------------"


time_from_sec() {
	local seconds=$1
	local hours=$((seconds / 60 / 60))
	local minutes=$(( (seconds / 60) - (hours * 60) ))

	[ $minutes -lt 0 ] && minutes=$((minutes * -1))
	printf '%02d:%02d' $hours $minutes
}

timedelta() {
	local date1="$(date --date "$1" +%s)"
	local date2="$(date --date "$2" +%s)"

	local seconds=$((date2 - date1))
	echo $seconds
}

# login/logout times buffer
timestr=""
timestr_last=""
datestr=""
datestr_last=""

# end-of-month log rotation
month_last=""
running_sec=0
work_sec=$(( ( (38 * 60 * 60) + (30 * 60) ) * 4))

while read -r line; do 
	echo "line: $line"

	for part in $line; do
		case $part in
		unlocking)
			locked=0
			echo "found unlock time"
			;;
		locking)
			locked=1
			echo "found lock time"
			;;
		*-*-*)
			datestr_last="$datestr"
			datestr="$part"
			;;
		*:*:*)
			timestr_last="$timestr"
			timestr="$part"
			;;
		*)
			# we don't care about anything else
			;;
		esac
	done

	# calc work time when a full set of unlock-lock has been found
	if [ $locked -eq 1 ] && [ -n "$datestr" ] && [ -n "$datestr_last" ]; then
		# calc time from last unlock
		echo "calculating worktime between $datestr_last $timestr_last and $datestr $timestr"

		seconds=$(timedelta "$datestr_last $timestr_last" "$datestr $timestr")
		running_sec=$((running_sec + seconds))
		delta="$(time_from_sec "$seconds")"

		echo "seconds: $seconds"
		echo "running_sec: $running_sec"

		# rotate log on month change
		month="${datestr:3:2}"
		if [ -z "$month_last" ]; then
			month_last="$month"
		elif [ "$month_last" != "$month" ]; then
			echo "NEW_MONTH_DETECTED - old log moved to ${timesheet_path}_${month_last}"
			total_time=$(time_from_sec $running_sec)
			abs_sec=$((running_sec - work_sec))
			abs_total="$(time_from_sec "$abs_sec")"
			printf '\n%s\nTOTAL    [ %s ] (%s)\n ' $timesheet_line $total_time $abs_total >> "$timesheet_path"
			running_sec=0
			mv "$timesheet_path" "${timesheet_path}_${month_last}"
		fi

		# log to timesheet file
		[ -f "$timesheet_path" ] || { echo "$timesheet_header" > "$timesheet_path"; }
		printf '%s %s   %s %s   [ %s ]\n' $datestr_last $timestr_last $datestr $timestr $delta >> "$timesheet_path"

		# and reset for next pair
		datestr=""
		timestr=""
	fi

done < "$locktime_path"

cat "$timesheet_path"
