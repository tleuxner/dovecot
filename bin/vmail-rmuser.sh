#!/bin/sh
# Disable Mail Account in LDAP scheme:
# https://github.com/tleuxner/ldap-virtualMail
# Thomas Leuxner <tlx@leuxner.net> 10-11-2021

. ldap_binds.inc
. msg_formatted.inc

if [ $# -eq 0 ]; then
    echo "usage: $0 user@domain" >&2
    exit 1
fi

confirm_yn() {
  while :; do
        read -p "$1" yn
        case $yn in
                [Yy]* ) return 0;;
                [Nn]* ) return 1;;
                * ) echo 'Please answer [y/n].';;
        esac
  done
}

# Split out domain part from $1 user@domain
local_part=${1%@*}
domain_part=${1#*@}

# Check for hosted domains
vmail_domain_hosted=$(postmap -q $domain_part ldap:/etc/postfix/ldap/virtual_domains.cf)

if [ "$vmail_domain_hosted" != "$domain_part" ]; then
  msg_formatted "$i_warn Virtual domain ($domain_part) not found in directory! <<<"
  exit 1
else
  msg_formatted "$i_start Virtual domain ($domain_part) found in directory <<<"
fi

set -e

# Fetch distinguished name of user record
vmail_user_dn=$(ldapsearch -LLL -ZZ -D $ldap_bind_dn -w $ldap_bind_dn_pw -H $ldap_server -b $ldap_search_base "(&(objectClass=mailUser)(mailDrop=$1))" dn)
[ -z "$vmail_user_dn" ] && { msg_formatted "$i_warn No valid mail user found." >&2; exit 1; }
msg_formatted "$i_step Selecting record ($vmail_user_dn) ..."

# Do we really want to create a new alias?
confirm_yn "Disable Account <$1> ? "

# Disable mailEnabled for record
ldap_ldif_entry="$vmail_user_dn\nchangetype: modify\nreplace: mailEnabled\nmailEnabled: FALSE"
msg_formatted "$i_step Committing LDIF Update ..."
printf "$ldap_ldif_entry" | ldapmodify -ZZ -D $ldap_bind_dn -w $ldap_bind_dn_pw -H $ldap_server | while read input; do
        msg_formatted "$i_step $input"
done

msg_formatted "$i_done Mail account has been disabled <<<"
