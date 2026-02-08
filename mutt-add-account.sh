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

auto_view text/html                                   # view HTML automatically
alternative_order text/plain text/enriched text/html  # save HTML for last

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
        ""
        "auto_view text/html                                   # view HTML automatically"
        "alternative_order text/plain text/enriched text/html  # save HTML for last"
        ""
    )
    
    for option in "${required_options[@]}"; do
        # Skip empty lines
        if [ -z "$option" ]; then
            continue
        fi
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

# Auto-detect mail server settings
email_domain="${email#*@}"
echo "Searching for server settings..."

# Try to get MX record and extract mail server
mx_record=$(dig +short MX "$email_domain" 2>/dev/null | sort -n | head -1 | awk '{print $2}' | sed 's/\.$//')

detection_failed=false

if [ -n "$mx_record" ]; then
    # Got MX record, try common IMAP server patterns
    base_domain=$(echo "$mx_record" | sed 's/^smtp\.//' | sed 's/^mx[0-9]*\.//' | sed 's/^mail\.//')
    
    # Try common IMAP server patterns
    if host "imap.$base_domain" &>/dev/null; then
        detected_imap="imap.$base_domain"
    elif host "mail.$base_domain" &>/dev/null; then
        detected_imap="mail.$base_domain"
    elif host "$mx_record" &>/dev/null; then
        detected_imap="$mx_record"
    else
        detected_imap="mail.${email_domain}"
    fi
    
    # Try to detect SMTP server
    if host "smtp.$base_domain" &>/dev/null; then
        detected_smtp="smtp.$base_domain"
    else
        detected_smtp="$detected_imap"
    fi
else
    # MX lookup failed - check if domain itself exists
    if host "$email_domain" &>/dev/null; then
        detected_imap="mail.${email_domain}"
        detected_smtp="mail.${email_domain}"
    else
        detection_failed=true
    fi
fi

if [ "$detection_failed" = false ]; then
    # Detect port by testing common ports
    detected_port="465"
    if timeout 2 bash -c "echo -n '' > /dev/tcp/$detected_smtp/587" 2>/dev/null; then
        detected_port="587"
    elif timeout 2 bash -c "echo -n '' > /dev/tcp/$detected_smtp/465" 2>/dev/null; then
        detected_port="465"
    fi

    # Show detected settings
    echo ""
    echo "Detected settings:"
    echo "  IMAP server: $detected_imap"
    echo "  SMTP server: $detected_smtp"
    echo "  SMTP port:   $detected_port"
    echo ""

    read -p "Are these settings correct? (y/n): " confirm

    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        # Use detected settings
        imap_server="$detected_imap"
        smtp_server="$detected_smtp"
        smtp_port="$detected_port"
    else
        # Manual entry
        echo "Please enter settings manually:"
        read -p "Enter IMAP server: " imap_server
        read -p "Enter SMTP server: " smtp_server
        read -p "Enter SMTP port (465 for SSL/TLS, 587 for STARTTLS) [465]: " smtp_port
        smtp_port=${smtp_port:-465}
    fi
else
    # Detection completely failed
    echo ""
    echo "Could not auto-detect mail server settings for $email_domain"
    echo "Please enter settings manually:"
    read -p "Enter IMAP server: " imap_server
    read -p "Enter SMTP server: " smtp_server
    read -p "Enter SMTP port (465 for SSL/TLS, 587 for STARTTLS) [465]: " smtp_port
    smtp_port=${smtp_port:-465}
fi

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
set folder = imaps://$email@$imap_server/
set spoolfile = +INBOX
set postponed = +Drafts
set record = +Sent
set status_format = "\$imap_user %f"
## Send options.
set smtp_url=$smtp_proto://$email@$smtp_server:$smtp_port
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
set folder = imaps://$email@$imap_server/
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
    echo "macro index,pager <f$next_fkey> '<sync-mailbox><enter-command>source $config_file<enter><change-folder>imaps://$email@$imap_server/INBOX<enter>'"
    echo ""
    echo "## ACCOUNT${account_num}"
    echo "source \"$config_file\""
    echo "folder-hook \"imaps://$email@$imap_server/\" 'source $config_file;'"
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
