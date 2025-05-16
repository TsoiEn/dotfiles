#!/bin/bash

BASE_DIR="/home/tsoipad/.config/scripts/pass"
PASSWORD_FILE="$BASE_DIR/passwords.enc"
KEY_FILE="$BASE_DIR/keyfile"
TEMP_FILE="$BASE_DIR/tempfile"
CIPHER="aes-256-cbc"

# Function to generate a random key if it does not exist
generate_key() {
    if [ ! -f "$KEY_FILE" ]; then
        openssl rand -base64 32 > "$KEY_FILE"
        chmod 600 "$KEY_FILE"
        echo "Generated key file: $KEY_FILE"
    fi
}

# Function to encrypt a password
encrypt_password() {
    echo "$1" | openssl enc -$CIPHER -salt -pbkdf2 -a -pass file:"$KEY_FILE"
}

# Function to decrypt a password
decrypt_password() {
    echo "$1" | openssl enc -d -$CIPHER -pbkdf2 -a -pass file:"$KEY_FILE"
}

# Function to generate a random password
generate_random_password() {
    head /dev/urandom | tr -dc A-Za-z0-9 | head -c 16
}

# Function to add a password
add_password() {
    read -p "Enter service name: " service
    read -sp "Enter password (leave empty to generate a random password): " password
    echo

    if [ -z "$password" ]; then
        password=$(generate_random_password)
        echo "Generated random password: $password"
    fi

    encrypted_password=$(encrypt_password "$password")

    if [ -f "$PASSWORD_FILE" ]; then
        decrypt_file
    fi

    echo "$service: $encrypted_password" >> "$TEMP_FILE"
    encrypt_file
    echo "Password added for service: $service"
}

# Function to retrieve a password
get_password() {
    read -p "Enter service name: " service

    if [ -f "$PASSWORD_FILE" ]; then
        decrypt_file
        encrypted_password=$(grep "^$service: " "$TEMP_FILE" | awk -F': ' '{print $2}')
        if [ -n "$encrypted_password" ]; then
            decrypted_password=$(decrypt_password "$encrypted_password")
            echo "Password for $service: $decrypted_password"
        else
            echo "No password found for service: $service"
        fi
        rm -f "$TEMP_FILE"
    else
        echo "No passwords stored yet."
    fi
}

# Function to encrypt the password file
encrypt_file() {
    openssl enc -$CIPHER -salt -pbkdf2 -in "$TEMP_FILE" -out "$PASSWORD_FILE" -pass file:"$KEY_FILE"
    rm -f "$TEMP_FILE"
}

# Function to decrypt the password file
decrypt_file() {
    openssl enc -d -$CIPHER -pbkdf2 -in "$PASSWORD_FILE" -out "$TEMP_FILE" -pass file:"$KEY_FILE"
}

# Function to list all services and their encrypted passwords
list_services() {
    if [ -f "$PASSWORD_FILE" ]; then
        decrypt_file
        printf "%-35s %-s\n" "Service" "Encrypted Password"
        printf "%-35s %-s\n" "-------" "------------------"
        while IFS=: read -r service encrypted_password; do
            printf "%-35s %s\n" "$service" "$encrypted_password"
        done < "$TEMP_FILE"
        rm -f "$TEMP_FILE"
    else
        echo "No passwords stored yet."
    fi
}

# Generate key if not present
generate_key

# Main menu
while true; do
    list_services
    read -p "
Password Manager
[1] Add
[2] Exit
Choose Option: " option
clear
    case $option in
        1)
            add_password 
            ;;
        2) 
            exit 0 ;;
        "g")
            get_password
            ;;
        *) echo "Invalid option" ;;
    esac
done
