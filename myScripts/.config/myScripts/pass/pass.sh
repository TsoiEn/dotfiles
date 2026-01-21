#!/bin/bash

# Use environment variable or default to /data for Docker compatibility
BASE_DIR="${PASSMAN_DATA_DIR:-$HOME/.config/myScripts/pass}"
PASSWORD_FILE="$BASE_DIR/passwords.enc"
KEY_FILE="$BASE_DIR/keyfile"
TEMP_FILE="$BASE_DIR/tempfile"
CIPHER="aes-256-cbc"

# Ensure BASE_DIR exists
mkdir -p "$BASE_DIR"

# Function to generate a random key if it does not exist
generate_key() {
  if [ ! -f "$KEY_FILE" ]; then
    openssl rand -base64 32 >"$KEY_FILE"
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

# Function to generate a random password with special characters
generate_random_password() {
  tr -dc 'A-Za-z0-9!@#$%^&*()_+-=[]{}|;:,./<>?' </dev/urandom | head -c 16
}

# Function to add a password
add_password() {
  read -r -p "Enter service name: " service
  read -r -sp "Enter password (leave empty to generate a random password): " password
  echo

  if [ -z "$password" ]; then
    password=$(generate_random_password)
    echo "Generated random password: $password"
  fi

  encrypted_password=$(encrypt_password "$password")

  if [ -f "$PASSWORD_FILE" ]; then
    decrypt_file
  else
    # Create tempfile if it doesn't exist
    : >"$TEMP_FILE"
  fi

  echo "$service: $encrypted_password" >>"$TEMP_FILE"
  encrypt_file
  echo "Password added for service: $service"
}

# Function to retrieve a password
get_password() {
  read -r -p "Enter service name: " service

  if [ -f "$PASSWORD_FILE" ]; then
    decrypt_file
    encrypted_password=$(grep "^$service: " "$TEMP_FILE" | awk -F': ' '{print $2}')
    if [ -n "$encrypted_password" ]; then
      decrypted_password=$(decrypt_password "$encrypted_password")

      if command -v wl-copy &>/dev/null; then
        echo -n "$decrypted_password" | wl-copy
        echo "Password for '$service' has been copied to the clipboard."
      else
        echo "Password for '$service': $decrypted_password"
      fi
    else
      echo "No password found for service: $service"
    fi
    rm -f "$TEMP_FILE"
  else
    echo "No passwords stored yet."
  fi
}

# Function to delete a password
delete_password() {
  read -r -p "Enter service name to delete: " service

  if [ -f "$PASSWORD_FILE" ]; then
    decrypt_file
    if grep -q "^$service: " "$TEMP_FILE"; then
      grep -v "^$service: " "$TEMP_FILE" >"$TEMP_FILE.tmp"
      mv "$TEMP_FILE.tmp" "$TEMP_FILE"
      encrypt_file
      echo "Password deleted for service: $service"
    else
      echo "No password found for service: $service"
      rm -f "$TEMP_FILE"
    fi
  else
    echo "No passwords stored yet."
  fi
}

# Function to update a password
update_password() {
  read -r -p "Enter service name to update: " service

  if [ -f "$PASSWORD_FILE" ]; then
    decrypt_file
    if grep -q "^$service: " "$TEMP_FILE"; then
      read -r -sp "Enter new password (leave empty to generate a random password): " password
      echo

      if [ -z "$password" ]; then
        password=$(generate_random_password)
        echo "Generated random password: $password"
      fi

      encrypted_password=$(encrypt_password "$password")
      grep -v "^$service: " "$TEMP_FILE" >"$TEMP_FILE.tmp"
      echo "$service: $encrypted_password" >>"$TEMP_FILE.tmp"
      mv "$TEMP_FILE.tmp" "$TEMP_FILE"
      encrypt_file
      echo "Password updated for service: $service"
    else
      echo "No password found for service: $service"
      rm -f "$TEMP_FILE"
    fi
  else
    echo "No passwords stored yet."
  fi
}

# Function to search/filter services
search_services() {
  read -r -p "Enter search term: " search_term

  if [ -f "$PASSWORD_FILE" ]; then
    decrypt_file
    results=$(grep -i "$search_term" "$TEMP_FILE")
    if [ -n "$results" ]; then
      printf "%-35s %-s\n" "Service" "Encrypted Password"
      printf "%-35s %-s\n" "-------" "------------------"
      echo "$results" | while IFS=: read -r service encrypted_password; do
        printf "%-35s %s\n" "$service" "$encrypted_password"
      done
    else
      echo "No services found matching: $search_term"
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
    done <"$TEMP_FILE"
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
  read -r -p "
Password Manager
[a] Add
[d] Delete
[e] Exit
[g] Get Password
[s] Search
[u] Update
Choose Option: " option
  clear
  case $option in
  a)
    add_password
    ;;
  d)
    delete_password
    ;;
  e)
    exit 0
    ;;
  g)
    get_password
    ;;
  s)
    search_services
    ;;
  u)
    update_password
    ;;
  *) echo "Invalid option" ;;
  esac
done
