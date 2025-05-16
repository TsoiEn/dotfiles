#!/bin/bash

#===========================================
# ESSENTIALS
#===========================================

# Function to display ASCII art
asscii1() {
cat << 'EOF'
      ___           ___           ___                    ___           ___           ___           ___           ___           ___           ___     
     /\  \         /\__\         /\  \                  /\__\         /\  \         /\__\         /\  \         /\  \         /\  \         /\  \    
    /::\  \       /:/  /        /::\  \                /::|  |       /::\  \       /::|  |       /::\  \       /::\  \       /::\  \       /::\  \   
   /:/\:\  \     /:/__/        /:/\:\  \              /:|:|  |      /:/\:\  \     /:|:|  |      /:/\:\  \     /:/\:\  \     /:/\:\  \     /:/\:\  \  
  /::\~\:\  \   /::\__\____   /:/  \:\  \            /:/|:|__|__   /::\~\:\  \   /:/|:|  |__   /::\~\:\  \   /:/  \:\  \   /::\~\:\  \   /::\~\:\  \ 
 /:/\:\ \:\__\ /:/\:::::\__\ /:/__/_\:\__\          /:/ |::::\__\ /:/\:\ \:\__\ /:/ |:| /\__\ /:/\:\ \:\__\ /:/__/_\:\__\ /:/\:\ \:\__\ /:/\:\ \:\__\
 \/__\:\/:/  / \/_|:|~~|~    \:\  /\ \/__/          \/__/~~/:/  / \/__\:\/:/  / \/__|:|/:/  / \/__\:\/:/  / \:\  /\ \/__/ \:\~\:\ \/__/ \/_|::\/:/  /
      \::/  /     |:|  |      \:\ \:\__\                  /:/  /       \::/  /      |:/:/  /       \::/  /   \:\ \:\__\    \:\ \:\__\      |:|::/  / 
       \/__/      |:|  |       \:\/:/  /                 /:/  /        /:/  /       |::/  /        /:/  /     \:\/:/  /     \:\ \/__/      |:|\/__/  
                  |:|  |        \::/  /                 /:/  /        /:/  /        /:/  /        /:/  /       \::/  /       \:\__\        |:|  |    
                   \|__|         \/__/                  \/__/         \/__/         \/__/         \/__/         \/__/         \/__/         \|__|    
EOF
}

asscii2() {
    cat << 'EOF'
                  ___           ___           ___           ___           ___       ___ 
      ___        /\__\         /\  \         /\  \         /\  \         /\__\     /\__\
     /\  \      /::|  |       /::\  \        \:\  \       /::\  \       /:/  /    /:/  /
     \:\  \    /:|:|  |      /:/\ \  \        \:\  \     /:/\:\  \     /:/  /    /:/  / 
     /::\__\  /:/|:|  |__   _\:\~\ \  \       /::\  \   /::\~\:\  \   /:/  /    /:/  /  
  __/:/\/__/ /:/ |:| /\__\ /\ \:\ \ \__\     /:/\:\__\ /:/\:\ \:\__\ /:/__/    /:/__/   
 /\/:/  /    \/__|:|/:/  / \:\ \:\ \/__/    /:/  \/__/ \/__\:\/:/  / \:\  \    \:\  \   
 \::/__/         |:/:/  /   \:\ \:\__\     /:/  /           \::/  /   \:\  \    \:\  \  
  \:\__\         |::/  /     \:\/:/  /     \/__/            /:/  /     \:\  \    \:\  \ 
   \/__/         /:/  /       \::/  /                      /:/  /       \:\__\    \:\__\
                 \/__/         \/__/                       \/__/         \/__/     \/__/
EOF
}

asscii3() {
    cat << 'EOF'
      ___           ___                       ___           ___           ___           ___           ___       ___ 
     /\__\         /\__\          ___        /\__\         /\  \         /\  \         /\  \         /\__\     /\__\
    /:/  /        /::|  |        /\  \      /::|  |       /::\  \        \:\  \       /::\  \       /:/  /    /:/  /
   /:/  /        /:|:|  |        \:\  \    /:|:|  |      /:/\ \  \        \:\  \     /:/\:\  \     /:/  /    /:/  / 
  /:/  /  ___   /:/|:|  |__      /::\__\  /:/|:|  |__   _\:\~\ \  \       /::\  \   /::\~\:\  \   /:/  /    /:/  /  
 /:/__/  /\__\ /:/ |:| /\__\  __/:/\/__/ /:/ |:| /\__\ /\ \:\ \ \__\     /:/\:\__\ /:/\:\ \:\__\ /:/__/    /:/__/   
 \:\  \ /:/  / \/__|:|/:/  / /\/:/  /    \/__|:|/:/  / \:\ \:\ \/__/    /:/  \/__/ \/__\:\/:/  / \:\  \    \:\  \   
  \:\  /:/  /      |:/:/  /  \::/__/         |:/:/  /   \:\ \:\__\     /:/  /           \::/  /   \:\  \    \:\  \  
   \:\/:/  /       |::/  /    \:\__\         |::/  /     \:\/:/  /     \/__/            /:/  /     \:\  \    \:\  \ 
    \::/  /        /:/  /      \/__/         /:/  /       \::/  /                      /:/  /       \:\__\    \:\__\
     \/__/         \/__/                     \/__/         \/__/                       \/__/         \/__/     \/__/
EOF
}

# Function to update and upgrade using nala
update_and_upgrade() {
    sudo nala update
    sudo nala upgrade -y
}

# Helper function for package installation or uninstallation
package_operation() {
    local operation=$1
    read -p "
===================================
Package Managers:
[1] apt/nala
[2] snap
[3] flatpak
[4] brew
===================================
: " cpkg

    case $cpkg in
        1)
            read -p "Search application name: " item
            if [ "$operation" = "uninstall" ]; then
                if dpkg-query -W -f='${Status}\n' "$item" 2>/dev/null | grep -q "install ok installed"; then
                    echo "$item is installed."
                    read -p "Do you want to $operation [y/n]: " confirmation
                    if [ "$confirmation" = "y" ]; then
                        sudo nala remove "$item"
                    elif [ "$confirmation" = "n" ]; then
                        exit 1
                    else
                        echo "Invalid option"
                    fi
                else
                    echo "$item is not installed."
                fi
            else
                sudo nala search "$item"
                read -p "Do you want to $operation [y/n]: " confirmation
                if [ "$confirmation" = "y" ]; then
                    update_and_upgrade
                    sudo nala install "$item"
                elif [ "$confirmation" = "n" ]; then
                    exit 1
                else 
                    echo "Invalid option"
                fi
            fi
            delay 5
            ;;
        2)
            read -p "Search application name: " item
            sudo snap search "$item"
            read -p "Do you want to $operation [y/n]: " confirmation
            if [ "$confirmation" = "y" ]; then
                update_and_upgrade
                sudo snap $operation "$item"
            elif [ "$confirmation" = "n" ]; then
                exit 1
            else 
                echo "Invalid option"
            fi
            ;;
        3)
            read -p "Search application name: " item
            flatpak search "$item"
            read -p "Do you want to $operation [y/n]: " confirmation
            if [ "$confirmation" = "y" ]; then
                read -p "Paste the ID: " pkgID
                flatpak $operation "$pkgID"
            elif [ "$confirmation" = "n" ]; then
                exit 1
            else 
                echo "Invalid option"
            fi
            ;;
        4)
            read -p "Search application name: " item
            brew search "$item"
            read -p "Do you want to $operation [y/n]: " confirmation
            if [ "$confirmation" = "y" ]; then
                brew $operation "$item"
            elif [ "$confirmation" = "n" ]; then
                exit 1
            else 
                echo "Invalid option"
            fi
            ;;
        *)
            echo "Invalid package manager option"
            ;;
    esac

}

# Function to install packages
install() {
    clear
    asscii2
    package_operation "install"
}

# Function to uninstall packages
uninstall() {
    clear
    asscii3
    package_operation "uninstall"
}

while true; do
    clear
    asscii1

    read -p "
===================================
Options:
===================================
[1] Install
[2] Uninstall
[q] Quit
------------ 
: " options

    case $options in
        1)
            install ;;
        2)
            uninstall ;;
        "q")
            clear
            exit 0 
            ;;
        *)
            echo "Invalid Option" ;;
    esac
done
