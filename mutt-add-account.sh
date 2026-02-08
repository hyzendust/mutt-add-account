#!/bin/bash

set -e

echo "=== Mutt Account Setup Script ==="
echo

# Check if .muttrc exists, if not create it with default settings
mutt_config="$HOME/.muttrc"
if [ ! -f "$mutt_config" ]; then
    echo "Creating new .muttrc with default settings..."
    cat > "$mutt_config" << 'MUTTRC_EOF'
## General options
set header_cache = "~/.cache/mutt"
set imap_check_subscribed
set imap_keepalive = 300
unset imap_passive
set mail_check = 15
set timeout = 10
set mbox_type=Maildir
set use_envelope_from = yes
set sort=reverse-date
set ssl_verify_host = no
MUTTRC_EOF
    echo "Created ~/.muttrc"
else
    # Check and update/add required options
    required_options=(
        "set header_cache = \"~/.cache/mutt\""
        "set imap_check_subscribed"
        "set imap_keepalive = 300"
        "unset imap_passive"
        "set mail_check = 15"
        "set timeout = 10"
        "set mbox_type=Maildir"
        "set use_envelope_from = yes"
        "set sort=reverse-date"
        "set ssl_verify_host = no"
    )
    
    for option in "${required_options[@]}"; do
        option_name=$(echo "$option" | awk '{print $1, $2}')
        if grep -q "^${option_name}" "$mutt_config"; then
            # Option exists, update it
            sed -i "s|^${option_name}.*|${option}|" "$mutt_config"
        else
            # Option doesn't exist, add it at the top
            sed -i "1i${option}" "$mutt_config"
        fi
    done
fi

# Get user inputs
read -p "Enter your full email address: " email
read -p "Enter your full name: " fullname
read -sp "Enter password: " password
echo
read -p "Enter account name: " shortname
read -p "Enter IMAP server: " imap_server
read -p "Enter SMTP server (Press Enter if same as IMAP server): " smtp_server
smtp_server=${smtp_server:-$imap_server}
read -p "Enter SMTP port (465 for SSL/TLS, 587 for STARTTLS) [465]: " smtp_port
smtp_port=${smtp_port:-465}

# Extract username from email
username="${email%%@*}"

# Determine SMTP protocol and TLS settings
if [ "$smtp_port" = "587" ]; then
    smtp_proto="smtp"
    smtp_starttls="set ssl_starttls = yes"
    use_starttls=true
else
    smtp_proto="smtps"
    smtp_starttls="unset ssl_starttls"
    use_starttls=false
fi

# Find next available F-key
next_fkey=2
while grep -q "<f$next_fkey>" "$mutt_config"; do
    ((next_fkey++))
done

# Find next account number
if grep -q "^## ACCOUNT" "$mutt_config"; then
    max_account=$(grep "^## ACCOUNT" "$mutt_config" | sed 's/## ACCOUNT//' | sort -n | tail -1)
    account_num=$((max_account + 1))
else
    account_num=1
fi

echo
echo "Using F$next_fkey for this account (ACCOUNT$account_num)"
echo "SMTP: $smtp_proto on port $smtp_port"
echo

# Create .mutt directory if it doesn't exist
mkdir -p "$HOME/.mutt"

# Config file will be named after the account name
config_file="$HOME/.mutt/${shortname}"

# Escape password for use in double quotes (for IMAP)
# Escape backslashes first, then double quotes, then dollar signs, then backticks
escaped_pass="${password//\\/\\\\}"
escaped_pass="${escaped_pass//\"/\\\"}"
escaped_pass="${escaped_pass//\$/\\\$}"
escaped_pass="${escaped_pass//\`/\\\`}"

# URL encode password for SMTP
encoded_pass=""
for ((i=0; i<${#password}; i++)); do
    c="${password:$i:1}"
    case "$c" in
        [a-zA-Z0-9.~_-]) 
            encoded_pass+="$c"
            ;;
        *)
            printf -v hex '%02X' "'$c"
            encoded_pass+="%$hex"
            ;;
    esac
done

# Create config file
if [ "$use_starttls" = true ]; then
    # STARTTLS - hardcode both passwords
    cat > "$config_file" << EOF
## Receive options.
set imap_user=$email
set imap_pass="$escaped_pass"
set folder = imaps://$username@$imap_server/
set spoolfile = +INBOX
set postponed = +Drafts
set record = +Sent
set status_format = "\$imap_user %f"
## Send options.
set smtp_url=$smtp_proto://$username@$smtp_server:$smtp_port
set smtp_pass="$escaped_pass"
set smtp_authenticators="plain:login"
set from="$email"
set use_from=yes
set realname='$fullname'
set hostname="$smtp_server"
set signature="$fullname"
# Connection options
set ssl_force_tls = yes
$smtp_starttls
EOF
else
    # SSL/TLS - hardcode IMAP password, embed URL-encoded password in smtp_url
    cat > "$config_file" << EOF
## Receive options.
set imap_user=$email
set imap_pass="$escaped_pass"
set folder = imaps://$username@$imap_server/
set spoolfile = +INBOX
set postponed = +Drafts
set record = +Sent
set status_format = "\$imap_user %f"
## Send options.
set smtp_url=$smtp_proto://$email:$encoded_pass@$smtp_server:$smtp_port
set smtp_authenticators="plain:login"
set from="$email"
set use_from=yes
set realname='$fullname'
set hostname="$smtp_server"
set signature="$fullname"
# Connection options
set ssl_force_tls = yes
$smtp_starttls
EOF
fi

echo "Created config file: $config_file"

# Backup .muttrc
cp "$mutt_config" "${mutt_config}.backup.$(date +%Y%m%d_%H%M%S)"
echo "Backed up .muttrc"

# Find insertion point
if grep -q "^## ACCOUNT" "$mutt_config"; then
    line_num=$(grep -n "^## ACCOUNT" "$mutt_config" | head -1 | cut -d: -f1)
    ((line_num--))
else
    line_num=$(wc -l < "$mutt_config")
fi

# Add account to .muttrc
{
    head -n "$line_num" "$mutt_config"
    echo "# Switch to account ${account_num} (${shortname})"
    echo "macro index,pager <f$next_fkey> '<sync-mailbox><enter-command>source $config_file<enter><change-folder>imaps://$username@$imap_server/INBOX<enter>'"
    echo ""
    echo "## ACCOUNT${account_num}"
    echo "source \"$config_file\""
    echo "folder-hook \"imaps://$username@$imap_server/\" 'source $config_file;'"
    echo
    tail -n +$((line_num + 1)) "$mutt_config"
} > "${mutt_config}.tmp"

mv "${mutt_config}.tmp" "$mutt_config"

echo
echo "=== Setup Complete ==="
echo "Account: $email"
echo "Config: $config_file"
echo "Press F$next_fkey in mutt to switch to this account"
echo
echo "Restart mutt to use the new account."
