#!/bin/sh
set -e
# Update Dovecot user password in LDAP
# Custom scheme: https://github.com/tleuxner/ldap-virtualMail
# Thomas Leuxner <tlx@leuxner.net> 01-11-2018
#
ldap_server='ldap://ldap.example.com/'
ldap_bind_dn='cn=admin,dc=example,dc=com'
ldap_bind_dn_pw='secret'
ldap_search_base='ou=Users,ou=Mail,dc=example,dc=com'

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

# Do we have that user already?
doveadm user -u $1 || { printf '\nUser does not exist.\n' >&2; exit 1; }

# Do we really want to create a new user?
confirm_yn "Set *new* password for user \"$1\" ? "

ldap_user_dn=$(ldapsearch -LLL -ZZ -D $ldap_bind_dn -w $ldap_bind_dn_pw -H $ldap_server -b $ldap_search_base "(&(objectclass=mailUser)(mailDrop=$1))" dn)
msg_formatted "$i_start Selecting record ($ldap_user_dn) <<<"

# Read password for user from input
password_hash=$(mkpasswd --rounds 5000 -m sha-512 --salt $(head -c 40 /dev/urandom | base64 | sed -e 's/+/./g' | cut -b 10-25))
ldap_ldif_entry="$ldap_user_dn\nchangetype: modify\nreplace: userPassword\nuserPassword: {CRYPT}$password_hash"

msg_formatted "$i_step Committing LDIF Update ($ldap_user_dn) ..."
printf "$ldap_ldif_entry" | ldapmodify -ZZ -D $ldap_bind_dn -w $ldap_bind_dn_pw -H $ldap_server
msg_formatted "$i_done Password has been updated $date <<<"
