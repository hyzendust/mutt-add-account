#!/bin/bash

set -e

echo "=== Mutt Account Setup Script ==="
echo

# Get user inputs
read -p "Enter your full email address (e.g., user@disroot.org): " email
read -p "Enter your full name: " fullname
read -sp "Enter your email password: " password
echo
read -p "Enter account short name (e.g., psy32nd): " shortname
read -p "Enter IMAP server (e.g., disroot.org): " imap_server
read -p "Enter SMTP server (default: same as IMAP): " smtp_server
smtp_server=${smtp_server:-$imap_server}

# Extract username from email (part before @)
username="${email%%@*}"

# Determine next available function key
mutt_config="$HOME/.muttrc"
if [ ! -f "$mutt_config" ]; then
    echo "Error: ~/.muttrc not found!"
    exit 1
fi

# Find next available F-key
next_fkey=2
while grep -q "<f$next_fkey>" "$mutt_config"; do
    ((next_fkey++))
done

# Find next account number by counting existing ACCOUNT sections
if grep -q "^## ACCOUNT" "$mutt_config"; then
    # Get the highest account number
    max_account=$(grep "^## ACCOUNT" "$mutt_config" | sed 's/## ACCOUNT//' | sort -n | tail -1)
    account_num=$((max_account + 1))
else
    account_num=1
fi

echo
echo "Using F$next_fkey for this account (ACCOUNT$account_num)"
echo

# Create account directory
account_dir="$HOME/.mutt/${shortname}-${imap_server##*.}"
mkdir -p "$account_dir"

# Create password files
pass_file="$account_dir/pass"
smtp_pass_file="$account_dir/smtp-pass"

printf '%s' "$password" > "$pass_file"
chmod 600 "$pass_file"

# URL encode password for SMTP - proper encoding
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

printf '%s' "$encoded_pass" > "$smtp_pass_file"
chmod 600 "$smtp_pass_file"

# Create config file
config_file="$account_dir/config"

cat > "$config_file" << EOF
## Receive options.
set imap_user=$email
set imap_pass=\`cat $pass_file | tr -d '\n'\`
set folder = imaps://$email/
set spoolfile = +INBOX
set postponed = +Drafts
set record = +Sent
set status_format = "\$imap_user %f"
## Send options.
set smtp_url=smtps://$email:\`cat $smtp_pass_file | tr -d '\n'\`@$smtp_server:465
set realname='$fullname'
set from=$email
set hostname="$smtp_server"
set signature="$fullname"
# Connection options
set ssl_force_tls = yes
unset ssl_starttls
## Hook -- IMPORTANT!
account-hook "imaps://$email/" 'set imap_user="$email"; set imap_pass=\`cat $pass_file | tr -d '"'"'\n'"'"'\`'
EOF

echo "Created config file: $config_file"
echo "Created password files in: $account_dir"

# Backup .muttrc
cp "$mutt_config" "${mutt_config}.backup.$(date +%Y%m%d_%H%M%S)"
echo "Backed up .muttrc"

# Find the line to insert after (before first existing account or at end)
if grep -q "^## ACCOUNT" "$mutt_config"; then
    # Insert before first account section
    line_num=$(grep -n "^## ACCOUNT" "$mutt_config" | head -1 | cut -d: -f1)
    ((line_num--))
else
    # Append to end
    line_num=$(wc -l < "$mutt_config")
fi

# Create temp file with new content
{
    head -n "$line_num" "$mutt_config"
    echo "# Switch to account ${account_num} (${shortname})"
    echo "macro index,pager <f$next_fkey> '<sync-mailbox><enter-command>source $config_file<enter><change-folder>imaps://$email/INBOX<enter>'"
    echo ""
    echo "## ACCOUNT${account_num}"
    echo "source \"$config_file\""
    echo "folder-hook \"imaps://$email/\" 'source $config_file;'"
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
