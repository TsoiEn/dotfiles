#!/bin/bash

# Stack to keep track of directory history
declare -a dir_stack

# Function to show items in the directory
show_item() {
    local DIRECTORY=$1
    dir_stack+=("$DIRECTORY")
    local count=1
    declare -A dir_map

    echo "Directory: $(basename "$DIRECTORY")"
    for item in "$DIRECTORY"/*; do
        if [ -d "$item" ]; then
            echo "[$count] $(basename "$item")"
            dir_map[$count]="$item"
            ((count++))
        elif [ -f "$item" ]; then
            echo "[$count] $(basename "$item")"
            dir_map[$count]="$item"
            ((count++))
        fi
    done

    read -p "Enter Option: " choice

    if [ "$choice" = "c" ]; then
        clear
        create_item "$DIRECTORY"
    elif [ "$choice" = "q" ]; then
        exit
    elif [ "$choice" = "r" ]; then
        if [ "${#dir_stack[@]}" -le 1 ]; then
            echo "Cannot go back further."
            show_item
        else
            dir_stack=("${dir_stack[@]:0:${#dir_stack[@]}-1}")
            clear
            show_item "${dir_stack[-1]}"
        fi
    elif [ -d "${dir_map[$choice]}" ]; then
        clear
        show_item "${dir_map[$choice]}"
    elif [ -f "${dir_map[$choice]}" ]; then
        clear
        nvim "${dir_map[$choice]}"
    else
        echo "Invalid choice."
    fi
}

# Function to create a new directory or file
create_item() {
    local DIRECTORY=$1
    echo "Choose an option to create:"
    echo "[1] New directory"
    echo "[2] New Markdown file"

    read -p "Enter Option: " create_choice
    if [ "$create_choice" = "1" ]; then
        echo "Enter the name of the new directory: "
        read new_dir_name
        mkdir "$DIRECTORY/$new_dir_name"
        echo "Directory '$new_dir_name' created."
    elif [ "$create_choice" = "2" ]; then
        echo "Enter the name of the new Markdown file (without extension): "
        read new_file_name
        touch "$DIRECTORY/$new_file_name.md"
        echo "File '$new_file_name.md' created."
        nvim "$DIRECTORY/$new_file_name.md"
    elif [ "$create_choice" = "q" ]; then
        exit
    else
        echo "Invalid choice."
    fi
    show_item "$DIRECTORY"
}

# Directory to iterate through
DIRECTORY="$HOME/Development/Documentation"

# Check if the directory exists
if [ -d "$DIRECTORY" ]; then
    show_item "$DIRECTORY"
else
    echo "Directory does not exist."
fi
