#!/bin/sh
# Expunge old posts before certain date from ':public/<mailbox>' 
# Set basic parameters accordingly:
# year=2011, before_date=$year-mm-dd
# Actual Mailbox is read from command line
set -e
year=2017
before_date=$year-01-01
mailbox_owner=john@example.com
source_mailbox_base=':public/Mailing-Lists'
acl_admin_group='group=PublicMailboxAdmins'
acl_unlock_seq="$acl_admin_group delete expunge insert lookup post read write write-seen write-deleted"
acl_lock_seq="$acl_admin_group insert lookup post read write write-seen"

msg_formatted() {
  echo "$(date "+%b %d %H:%M:%S") $*"
}

if [ $# -eq 0 ]; then
    echo "usage: $0 mailbox"
    exit 1
fi

# Mailbox exists?
doveadm acl get -u $mailbox_owner "$source_mailbox_base/$1" || { echo 'Mailbox not found.'; exit 1; }

# Modify ACL, expunge mail and revert ACL
msg_formatted "[>] Expunging mail older than \"$before_date\" in \"$source_mailbox_base/$1\""

doveadm acl set -u $mailbox_owner "$source_mailbox_base/$1" $acl_unlock_seq
doveadm expunge -u $mailbox_owner mailbox "$source_mailbox_base/$1" before $before_date
doveadm acl set -u $mailbox_owner "$source_mailbox_base/$1" $acl_lock_seq

msg_formatted '[ Complete ]'
