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
set resolve = no

auto_view text/html                                   # view HTML automatically
alternative_order text/plain text/enriched text/html  # save HTML for last

source ~/.mutt/sidebar.muttrc
source ~/.mutt/vim-keys.rc
source ~/.mutt/vombatidae.neomuttrc

# Clear any default mailboxes before loading account configs
unmailboxes *

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
        "set resolve = no"
        ""
        "auto_view text/html                                   # view HTML automatically"
        "alternative_order text/plain text/enriched text/html  # save HTML for last"
        ""
        "source ~/.mutt/sidebar.muttrc"
        "source ~/.mutt/vim-keys.rc"
        "source ~/.mutt/vombatidae.neomuttrc"
        ""
        "# Clear any default mailboxes before loading account configs"
        "unmailboxes *"
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

# Create .mutt directory and subdirectories if they don't exist
mkdir -p "$HOME/.mutt/accounts"

# Create sidebar.muttrc if it doesn't exist
sidebar_file="$HOME/.mutt/sidebar.muttrc"
if [ ! -f "$sidebar_file" ]; then
    cat > "$sidebar_file" << 'SIDEBAR_EOF'
# Sidebar mappings
set sidebar_visible = yes
set sidebar_width = 20
set sidebar_short_path = yes
set sidebar_next_new_wrap = yes
set mail_check_stats
set sidebar_format = '%D%?F? [%F]?%* %?N?%N/? %?S?%S?'
bind index,pager \Ck sidebar-prev
bind index,pager \Cj sidebar-next
bind index,pager \Co sidebar-open
bind index,pager \Cp sidebar-prev-new
bind index,pager \Cn sidebar-next-new
bind index,pager B sidebar-toggle-visible

# Use named-mailboxes to show mailboxes in sidebar
# These will be populated dynamically by each account config
SIDEBAR_EOF
    echo "Created ~/.mutt/sidebar.muttrc"
fi

# Create vim-keys.rc if it doesn't exist
vim_keys_file="$HOME/.mutt/vim-keys.rc"
if [ ! -f "$vim_keys_file" ]; then
    cat > "$vim_keys_file" << 'VIMKEYS_EOF'
#------------------------------------------------------------
# Vi Key Bindings
#------------------------------------------------------------
# Moving around
bind attach,browser,index       g   noop
bind attach,browser,index       gg  first-entry
bind attach,browser,index       G   last-entry
bind pager                      g  noop
bind pager                      gg  top
bind pager                      G   bottom
bind pager                      k   previous-line
bind pager                      j   next-line
# Scrolling
bind attach,browser,pager,index \CF next-page
bind attach,browser,pager,index \CB previous-page
bind attach,browser,pager,index \Cu half-up
bind attach,browser,pager,index \Cd half-down
bind browser,pager              \Ce next-line
bind browser,pager              \Cy previous-line
bind index                      \Ce next-line
bind index                      \Cy previous-line
bind pager,index                d   noop
bind pager,index                dd  delete-message
# Mail & Reply
bind index                      \Cm list-reply # Doesn't work currently
# Threads
bind browser,pager,index        N   search-opposite
bind pager,index                dT  delete-thread
bind pager,index                dt  delete-subthread
bind pager,index                gt  next-thread
bind pager,index                gT  previous-thread
bind index                      za  collapse-thread
bind index                      zA  collapse-all # Missing :folddisable/foldenable
# Open mail
bind index <return> display-message
# Full headers
macro index h "<enter-command>unset weed<enter><display-message><enter-command>set weed<enter>" "show all headers"
macro pager h "<exit><enter-command>unset weed<enter><display-message><enter-command>set weed<enter>" "show all headers"
# Unmark all marked for deleted and tagged messages
bind index u noop
bind pager u noop
macro index u "<untag-pattern>~A<enter><tag-pattern>~A<enter><tag-prefix><undelete-message><untag-pattern>~A<enter>" "undelete all and untag"
macro pager u "<exit><untag-pattern>~A<enter><tag-pattern>~A<enter><tag-prefix><undelete-message><untag-pattern>~A<enter>" "undelete all and untag"
VIMKEYS_EOF
    echo "Created ~/.mutt/vim-keys.rc"
fi

# Create vombatidae.neomuttrc if it doesn't exist
vombat_file="$HOME/.mutt/vombatidae.neomuttrc"
if [ ! -f "$vombat_file" ]; then
    cat > "$vombat_file" << 'VOMBAT_EOF'
# NeoMutt color file
# Maintainer: Jon Häggblad <jon@haeggblad.com>
# URL: http://www.haeggblad.com
# Last Change: 2013 May 17
# Version: 0.1
#
# NeoMutt colorscheme loosely inspired by vim colorscheme wombat.vim.
#
# Changelog:
#   0.1 - Initial version
# --- vombatidae text colors ---
#  color normal         color230      color234
#  color message        color230      color234
# --- slightly less yellow text colors ---
color normal            color253        color234 # mod
# color normal          color253        color233 # mod
#  color normal         color253        default # mod
color indicator         color230        color238
color status            color101        color16
#  color tree           color113        color234
#  color tree           color173        color234
color tree              color208        color234
color signature         color102        color234
color message           color253        color234
color attachment        color117        color234
color error             color30         color234
color tilde             color130        color235
color search       color100     default
color markers      color138     default
#  mono bold          reverse
#  color bold         color173 color191
#  mono underline     reverse
#  color underline    color48  color191
color quoted        color107     color234             # quoted text
color quoted1       color66      color234
color quoted2       color32      color234
color quoted3       color30      color234
color quoted4       color99      color234
color quoted5       color36      color234
color quoted6       color114     color234
color quoted7       color109     color234
color quoted8       color41      color234
color quoted9       color138     color234
# color body          cyan  default  "((ftp|http|https)://|news:)[^ >)\"\t]+"
# color body          cyan  default  "[-a-z_0-9.+]+@[-a-z_0-9.]+"
# color body          red   default  "(^| )\\*[-a-z0-9*]+\\*[,.?]?[ \n]"
# color body          green default  "(^| )_[-a-z0-9_]+_[,.?]?[\n]"
# color body          red   default  "(^| )\\*[-a-z0-9*]+\\*[,.?]?[ \n]"
# color body          green default  "(^| )_[-a-z0-9_]+_[,.?]?[ \n]"
color index             color202        color234  ~F         # Flagged
color index             color39         color234  ~N          # New
color index             color39         color234  ~O
color index             color229        color22  ~T         # Tagged
color index             color240        color234  ~D         # Deleted
# ---
#mono body      reverse         '^(subject):.*'
#color body     brightwhite magenta     '^(subject):.*'
#mono body      reverse         '[[:alpha:]][[:alnum:]-]+:'
#color body     black cyan      '[[:alpha:]][[:alnum:]-]+:'
# --- header ---
color hdrdefault        color30         color233
color header            color132        color233    '^date:'
color header            color153        color233    '^(to|cc|bcc):'
color header            color120        color233    '^from:'
color header            color178        color233    '^subject:'
color header            color31         color233    '^user-agent:'
color header            color29         color233    '^reply-to:'
#color header   magenta default '^(status|lines|date|received|sender|references):'
#color header   magenta default '^(pr|mime|x-|user|return|content-)[^:]*:'
#color header   brightyellow default '^content-type:'
#color header   magenta default '^content-type: *text/plain'
# color header  brightgreen default '^list-[^:]*:'
#mono  header    bold               '^(subject):.*$'
#color header   brightcyan default      '^(disposition)'
#color header   green default   '^(mail-)?followup'
#color header   white default   '^reply'
#color header   brightwhite default     '^(resent)'
# color header  brightwhite default     '^from:'
#mono index     bold '~h "^content-type: *(multipart/(mixed|signed|encrypted)|application/)"'
#color index    green black '~h "^content-type: *multipart/(signed|encrypted)"'
#color sidebar_new color39 color234
VOMBAT_EOF
    echo "Created ~/.mutt/vombatidae.neomuttrc"
fi

# Create/update mbsync apparmor profile
apparmor_file="/etc/apparmor.d/mbsync"
if [ ! -f "$apparmor_file" ] && [ -d "/etc/apparmor.d" ]; then
    echo "Creating mbsync apparmor profile..."
    sudo tee "$apparmor_file" > /dev/null << 'APPARMOR_EOF'
#------------------------------------------------------------------
#    Copyright (C) 2024 Canonical Ltd.
#
#    Author: Eduardo Barretto <eduardo.barretto@canonical.com>
#
#    This program is free software; you can redistribute it and/or
#    modify it under the terms of version 2 of the GNU General Public
#    License published by the Free Software Foundation.
#------------------------------------------------------------------
# vim: ft=apparmor
abi <abi/4.0>,
include <tunables/global>
profile mbsync /usr/bin/mbsync {
  include <abstractions/base>
  include <abstractions/nameservice-strict>
  include <abstractions/ssl_certs>
  network inet dgram,
  network inet stream,
  network inet6 dgram,
  network inet6 stream,
  network netlink raw,
  @{etc_ro}/ssl/openssl.cnf rw,
  /usr/bin/mbsync rw,
  owner @{HOME}/.mbsyncrc rw,
  owner @{HOME}/Maildir/**/ rw,
  owner @{HOME}/Maildir/**/.mbsyncstate rw,
  owner @{HOME}/Maildir/**/.mbsyncstate.journal rw,
  owner @{HOME}/Maildir/**/.mbsyncstate.lock wk,
  owner @{HOME}/Maildir/**/.mbsyncstate.new rw,
  owner @{HOME}/Maildir/**/.uidvalidity rwk,
  owner @{HOME}/Maildir/**/cur/* rw,
  owner @{HOME}/Maildir/**/new/* rw,
  owner @{HOME}/Maildir/**/tmp/* rw,
  include if exists <local/mbsync>
}
APPARMOR_EOF
    echo "Created $apparmor_file"
    echo "Restarting apparmor service..."
    sudo systemctl restart apparmor.service 2>/dev/null || echo "Note: Could not restart apparmor service"
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

# Create Maildir directory for this account
maildir_path="$HOME/Maildir/${shortname}"
mkdir -p "$maildir_path"
echo "Created Maildir: $maildir_path"

# Config file will be in the accounts subdirectory
config_file="$HOME/.mutt/accounts/${shortname}"

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

# Create mutt config file with Maildir
cat > "$config_file" << EOF
## Receive options.
set imap_user=$email
set imap_pass="$escaped_pass"
set folder = ~/Maildir/${shortname}/
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

# Mailboxes for sidebar
unmailboxes *
named-mailboxes "INBOX" "=INBOX"
named-mailboxes "Drafts" "=Drafts"
named-mailboxes "Sent" "=Sent"
named-mailboxes "Junk" "=Junk"
named-mailboxes "Trash" "=Trash"
named-mailboxes "All" "=All"
EOF

echo "Created config file: $config_file"

# Create/append to .mbsyncrc
mbsync_config="$HOME/.mbsyncrc"
echo "Adding mbsync configuration..."

cat >> "$mbsync_config" << EOF

IMAPStore ${shortname}-remote
Host $imap_server
Port 993
User $email
Pass $password
SSLType IMAPS
CertificateFile /etc/ssl/certs/ca-certificates.crt

MaildirStore ${shortname}-local
Path ~/Maildir/${shortname}/
Inbox ~/Maildir/${shortname}/INBOX
Subfolders Verbatim

Channel $email
Far :${shortname}-remote:
Near :${shortname}-local:
Create Both
Expunge Both
Patterns *
SyncState *
MaxMessages 0
ExpireUnread no
# End profile

EOF

echo "Added mbsync profile to $mbsync_config"

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
    echo "macro index,pager <f$next_fkey> '<sync-mailbox><enter-command>source $config_file<enter><change-folder>~/Maildir/${shortname}/INBOX/<enter>'"
    echo ""
    echo "## ACCOUNT${account_num}"
    echo "source \"$config_file\""
    echo "folder-hook \"~/Maildir/${shortname}/\" 'source $config_file;'"
    echo
    tail -n +$((line_num + 1)) "$mutt_config"
} > "${mutt_config}.tmp"

mv "${mutt_config}.tmp" "$mutt_config"

echo
echo "=== Setup Complete ==="
echo "Account: $email"
echo "Mutt config: $config_file"
echo "Maildir: $maildir_path"
echo "Mbsync config: Added to $mbsync_config"
echo ""
echo "To sync mail, run: mbsync $email"
echo "Press F$next_fkey in mutt to switch to this account"
echo
echo "Restart mutt to use the new account."
