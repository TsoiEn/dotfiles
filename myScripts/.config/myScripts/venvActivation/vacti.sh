#!/usr/bin/env bash

# Check if the venv directory exists
if [ ! -d "./venv" ]; then
  echo "No venv directory found in current directory."
  exit 1
fi

# Check for the activate script
if [ -f "./venv/bin/activate" ]; then
  # shellcheck disable=SC1091
  source ./venv/bin/activate
  clear
  echo "venv is successfully activated."
else
  echo "No activate script found in ./venv/bin/activate"
  exit 1
fi
