#!/bin/bash

# Run as root

if [[ $EID -ne 0 ]]; then
	echo "Run this script as root" >&2
	exit 1
fi


# Check input

if [ -z "$1" ]; then
	echo "Usage: bash $0 <name-of-file-containing-employee-names-and-password>"
	exit 1
fi

INPUT_FILE=$1

# Check /var/secure

mkdir -p /var/secure
chmod 700 /var/secure

# Password file
PASSWORD_FILE="/var/secure/user_password.csv"

# Log Messages

log_message() {
	local MESSAGE=$1
	echo "$(date +'%Y-%m-%d %H:%M:%S') - $MESSAGE" >> /var/log/user_management.log
}

# Initialize log file

echo "User Management Script Log" > /var/log/user_management.log

# Initialize password file
#
echo "username,password" > $PASSWORD_FILE
chmod 600 $PASSWORD_FILE

# Read the input file

while IFS=';' read -r USERNAME GROUPS; do
	if [ -z "$USERNAME" ]; then
		continue
	fi

	# Remove whitespace
	USERNAME=$(echo "$USERNAME" | xargs)
	GROUPS=$(echo "$GROUPS" | xargs)

	# Create the user if it does not exist already
	if id "$USERNAME" &>/dev/null; then
		log_message "User $USERNAME already exists"
	else
		useradd -m -s /bin/bash "$USERNAME"
		log_message "Created user $USERNAME"
	fi

	# Create group for each user corresponding to username
	if ! getent group "$USERNAME" &>/dev/null; then
		groupadd "$USERNAME"
		log_message "Created personal group $USERNAME"
	fi

	# Add user to additional groups
	if [ -n "$GROUPS"]; then
		IFS=',' read -r -a GROUP_ARRAY <<< "$GROUPS"
			for GROUP in "${GROUP_ARRAY[@]}"; do
			# Remove whitespace
			GROUP=$(echo "$GROUP" | xargs)
			if !getent group "$GROUP" &>/dev/null; then
				groupadd "$GROUP"
				log_message "Created group $GROUP"
			fi
			usermod -aG "$GROUP" "$USERNAME"
			log_message "Added $USERNAME to group $GROUP"
		done
	fi

	# Set up home directory permissions
	chmod 700 /home/"$USERNAME"
	chmod "$USERNAME":"$USERNAME" /home/"$USERNAME"

	#Generate random password
	PASSWORD=$(openssl rand -base64 12)
	echo "$USERNAME,$PASSWORD" >> $PASSWORD_FILE
	echo "$USERNAME:$PASSWORD" | chpasswd
	log_message "Set password for user $USERNAME"
done < "$INPUT_FILE"

log_message "User creation process completed"
echo "Script executed sucessfully. Check /var/log/user_management.log for  details"

