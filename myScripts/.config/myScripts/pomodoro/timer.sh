#!/usr/bin/env bash

report() {
  local taskTitle=$1
  shift
  local todo=("$@")
  local startTime=${todo[-2]}
  local endTime=${todo[-1]}
  unset 'todo[-2]'
  unset 'todo[-1]'

  report_dir="$HOME/Development/report"
  mkdir -p "$report_dir"
  file="$report_dir/$(date +"%Y-%m-%d").md"

  {
    echo "--------"
    echo "# Task Title: $taskTitle"
    echo "## To Do:"
    for task in "${todo[@]}"; do
      echo "- $task"
    done
    echo "## Start: $startTime"
    echo "## End: $endTime"
    echo "--------"
    echo ""
  } >>"$file"
}

# Title of the task
read -r -p "What are you doing: " taskTitle

startTime=$(date +"%Y-%m-%d %I:%M:%S %p")

declare -a todo

countdown() {
  local seconds=$1
  while [ $seconds -gt 0 ]; do
    echo -ne "Time remaining: $seconds\033[0K\r"
    sleep 1
    ((seconds--))
  done
  echo -ne "\033[0K\r"
}

while true; do
  for _ in {1..4}; do
    read -r -p "What task are you doing: " task
    todo+=("$task")
    notify-send "Start Task"
    aplay notification.wav # Play sound
    clear
    countdown "$((300 * 5))" # 25-minute countdown

    aplay notification.wav # Play sound
    notify-send "Time to take a short break"
    clear
    countdown "$((60 * 5))" # 5-minute break countdown

    aplay notification.wav # Play sound

    # Ask if the user is done with the task
    read -r -p "Are you done (y/n): " choice
    if [ "$choice" = "y" ]; then
      endTime=$(date +"%Y-%m-%d %I:%M:%S %p")
      todo+=("$startTime" "$endTime")
      report "$taskTitle" "${todo[@]}"
      exit 0
    else
      notify-send "Time to get back to work"
    fi

  done
  notify-send "Time for a long break"
  countdown "$((15 * 60))" # 15-minute long break
  aplay notification.wav   # Play sound
  notify-send "Time to work"
done
