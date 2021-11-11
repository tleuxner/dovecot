#!/bin/sh
set -e
# Change password of virtual mail user
# https://github.com/tleuxner/ldap-virtualMail
# Thomas Leuxner <tlx@leuxner.net> 01-11-2018
#
# [16-11-2018]
# * moved LDAP binds to include
# [11-11-2021]
# * renamed variables and prompts to refer to vmail users

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

# Do we have that user?
doveadm user -u $1 || { printf '\n';msg_formatted "$i_warn User not found in directory! <<<" >&2; exit 1; }

# Do we really want to set a new password?
printf '\n'
confirm_yn "Set *new* password for vmail user <$1> ? "

vmail_user_dn=$(ldapsearch -LLL -ZZ -D $ldap_bind_dn -w $ldap_bind_dn_pw -H $ldap_server -b $ldap_search_base "(&(objectclass=mailUser)(mailDrop=$1))" dn)
msg_formatted "$i_start Selecting user record ($vmail_user_dn) <<<"

# Read password for user from input
password_hash=$(mkpasswd --rounds 5000 -m sha-512 --salt $(head -c 40 /dev/urandom | base64 | sed -e 's/+/./g' | cut -b 10-25))
ldap_ldif_entry="$vmail_user_dn\nchangetype: modify\nreplace: userPassword\nuserPassword: {CRYPT}$password_hash"

msg_formatted "$i_step Committing LDIF update ..."
printf "$ldap_ldif_entry" | ldapmodify -ZZ -D $ldap_bind_dn -w $ldap_bind_dn_pw -H $ldap_server | while read input; do
        msg_formatted "$i_step $input"
done

msg_formatted "$i_done Password has been updated <<<"
