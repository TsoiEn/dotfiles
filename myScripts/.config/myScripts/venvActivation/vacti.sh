#!/usr/bin/env bash

# Directories to check (priority: .venv, then venv)
for dir in .venv venv; do
  if [ -d "./$dir" ]; then
    if [ -f "./$dir/bin/activate" ]; then
      # shellcheck disable=SC1090
      source "./$dir/bin/activate"
      clear
      echo "$dir is successfully activated (bin/activate)."
      return 0
    elif [ -f "./$dir/Scripts/activate" ]; then
      # shellcheck disable=SC1090
      source "./$dir/Scripts/activate"
      clear
      echo "$dir is successfully activated (Scripts/activate)."
      return 0
    else
      echo "No activate script found in $dir"
      return 1
    fi
  fi
done

echo "No venv or .venv directory found in current directory."
return 1
