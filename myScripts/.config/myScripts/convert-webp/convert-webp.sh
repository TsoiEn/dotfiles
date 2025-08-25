#!/usr/bin/env bash

SOURCE_DIR="$(pwd)"
counter=1

for file in "$SOURCE_DIR"/*.webp; do
  [ -e "$file" ] || continue

  output=$(printf "$SOURCE_DIR/img%03d.jpg" "$counter")

  if dwebp "$file" -o "$output"; then
    echo "Converted: $file → $output"
    # rm "$file"
    ((counter++))
  else
    echo "Failed to convert: $file"
  fi
done
