#!/bin/bash

# Print starting time in 12-hour format with AM/PM
start_time_str=$(date '+%Y-%m-%d %I:%M:%S %p')
echo "Started at: $start_time_str"
echo " "

start_time=$(date +%s)

# Trap for CTRL-C
trap '
    echo
    end_time_str=$(date "+%Y-%m-%d %I:%M:%S %p")
    end_time=$(date +%s)
    elapsed=$((end_time - start_time))
    hours=$((elapsed / 3600))
    minutes=$(( (elapsed % 3600) / 60 ))
    seconds=$((elapsed % 60))
    echo " "
    printf "Stopped at: %s\n" "$end_time_str"
    printf "Total run time: %02d:%02d:%02d (hh:mm:ss)\n" "$hours" "$minutes" "$seconds"
    exit 0
' INT

while true; do
    now=$(date +%s)
    elapsed_seconds=$((now - start_time))
    elapsed_minutes=$((elapsed_seconds / 60))
    sec=$(date +'%S')
    sec_left=$((60 - 10#$sec))
    printf "\rSeconds left to next minute: %2d | Minutes elapsed: %2d" "$sec_left" "$elapsed_minutes"
    sleep 1
done

