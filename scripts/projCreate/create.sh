#!/bin/bash

cd ~/Development/github/projects/
clear

while true; do
    # Display ASCII art and options
    cat << 'EOF'
   _____                    _           _____          _____              _              _        
  / ____|                  | |         / ____|        |  __ \            (_)            | |       
 | |      _ __  ___   __ _ | |_  ___  | |  __   ___   | |__) |_ __  ___   _   ___   ___ | |_  ___ 
 | |     | '__|/ _ \ / _` || __|/ _ \ | | |_ | / _ \  |  ___/| '__|/ _ \ | | / _ \ / __|| __|/ __|
 | |____ | |  |  __/| (_| || |_|  __/ | |__| || (_) | | |    | |  | (_) || ||  __/| (__ | |_ \__ \
  \_____||_|   \___| \__,_| \__|\___|  \_____| \___/  |_|    |_|   \___/ | | \___| \___| \__||___/
                                                                        _/ |                      
                                                                       |__/   
EOF

    read -p "choose if normal, advance, or quit (n/a/q): " choice

    if [ "$choice" = "n" ]; then
        go-blueprint create
        sleep 5
        clear
    elif [ "$choice" = "a" ]; then
        go-blueprint create --advanced
        sleep 5
        clear
    elif [ "$choice" = "q" ]; then
        clear
        exit 0
    else
        clear
        echo "Invalid Choice!!!"
        continue
    fi
done
