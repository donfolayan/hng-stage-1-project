#!/bin/bash

# Ensure script runs as root (check and exit if not)
if [[ $EUID -ne 0 ]]; then
  echo "Error: This script requires root privileges."
  echo "Please run with sudo: sudo ./create_users.sh"
  exit 1
fi

# Check if input file provided
if [ $# -eq 0 ]; then
  echo "Error: Please provide an input file name as an argument."
  exit 1
fi

input_file="$1"

# Function for logging messages
log_message() {
  local message="$1"
  echo "$(date +'%Y-%m-%d %H:%M:%S') - $message" >> /var/log/user_management.log
}

# Function for adding to group
group_add() {
  IFS=',' read -ra group_array <<< "$groups"  # Read groups into an array
  for group in "${group_array[@]}"; do
    if ! getent group "$group" &>/dev/null; then
      groupadd "$group"
      log_message "Created group '$group'."
    fi
    usermod -a -G "$group" "$username"
    log_message "User: $username added to group: $group"
  done
}


# Create necessary directories with permissions
mkdir -p /var/secure /var/log
chmod 750 /var/secure /var/log

# Initialize log file
touch /var/log/user_management.log
chmod 640 /var/log/user_management.log

# Initialize password file with secure permissions
touch /var/secure/user_passwords.csv
chmod 600 /var/secure/user_passwords.csv

# Loop through each line in the input file
while IFS=';' read -r username groups; do

  # Remove leading/trailing whitespace
  username="${username##* }"
  username="${username%% *}"
  groups="${groups##* }"
  groups="${groups%% *}"

  # Skip empty lines
  if [ -z "$username" ]; then
    continue
  fi
  
  # Check if user exists
  if id "$username" &>/dev/null; then
    log_message "User $username already exists"
    group_add 
   continue
  else
  # Create user and personal group
    useradd -m -s /bin/bash "$username"
    log_message "Created user '$username' and group '$username'."
  fi

  # Create/add user to additional groups
  if [ -n "$groups" ]; then
    IFS=',' read -ra groupName <<< "$groups"
    for group in $(echo "$groups" | tr ',' ' '); do
      if ! getent group "$group" &>/dev/null; then
        groupadd "$group"
        log_message "Created group '$group'."
      fi
    usermod -a -G "$group" "$username"
    log_message "User: $username added to group: $group"
    done
  fi

  # Ensure home directory exists and set permissions
  home_dir="/home/$username"
  if [ ! -d "$home_dir" ]; then
    mkdir "$home_dir"
  fi
  chown "$username:$username" "$home_dir"
  chmod 700 "$home_dir"

  # Generate random password, store securely, and update log
  password=$(head /dev/urandom | tr -dc A-Za-z0-9 | fold -w 16 | head -n 1)
  echo "$username,$password" >> /var/secure/user_passwords.csv
  log_message "Generated password for user '$username' and stored securely."

  # Set user password
  echo "$username:$password" | chpasswd -e /etc/shadow

  # Successful user creation
  echo "User '$username' created successfully with password stored in /var/secure/user_passwords.csv (READ-ONLY)."
  log_message "User '$username' creation completed."

done < "$input_file"

echo "User creation script completed. Refer to /var/log/user_management.log for details."
