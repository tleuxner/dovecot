#!/bin/sh
set -e
# Create new nail alias using LDAP scheme:
# https://github.com/tleuxner/ldap-virtualMail
# Thomas Leuxner <tlx@leuxner.net> 15-11-2018
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

# Is this alias already in use?
ldap_alias_dn=$(ldapsearch -LLL -ZZ -D $ldap_bind_dn -w $ldap_bind_dn_pw -H $ldap_server -b $ldap_search_base "(&(objectClass=mailUser)(mailAlias=$1))" dn)
[ -z "$ldap_alias_dn" ] || { printf "$i_warn Alias already exists:\n$ldap_alias_dn\n" >&2; exit 1; }

# Add alias to Dovecot user
read -p "$i_step Add alias to which user: " ldap_maildrop

# Do we have that user already?
doveadm user -u $ldap_maildrop || { printf "$i_warn No valid mail user found.\n" >&2; exit 1; }

ldap_user_dn=$(ldapsearch -LLL -ZZ -D $ldap_bind_dn -w $ldap_bind_dn_pw -H $ldap_server -b $ldap_search_base "(&(objectClass=mailUser)(mailDrop=$ldap_maildrop))" dn)
msg_formatted "$i_step Selecting record \"$ldap_user_dn\" ..."

# Do we really want to create a new alias?
confirm_yn "Create *new* alias \"$1\" ? "

# Update mailAlias
ldap_ldif_entry="$ldap_user_dn\nchangetype: modify\nadd: mailAlias\nmailAlias: $1"

msg_formatted "$i_step Committing LDIF Update ($ldap_user_dn) ..."
printf "$ldap_ldif_entry" | ldapmodify -ZZ -D $ldap_bind_dn -w $ldap_bind_dn_pw -H $ldap_server

msg_formatted "$i_done Alias has been created $date <<<"
