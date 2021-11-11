#!/bin/sh
# Create new Mail Domain using LDAP scheme:
# https://github.com/tleuxner/ldap-virtualMail
# Thomas Leuxner <tlx@leuxner.net> 21-01-2019

. ldap_admin_binds.inc
. msg_formatted.inc

if [ $# -eq 0 ]; then
    echo "usage: $0 domain" >&2
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

# Check for hosted domains.
vmail_domain_hosted=$(postmap -q $1 ldap:/etc/postfix/ldap/virtual_domains.cf)

if [ "$vmail_domain_hosted" = "$1" ]; then
  msg_formatted "$i_warn Virtual Domain ($1) already in directory! <<<"
  exit 1
else
  msg_formatted "$i_start Virtual domain ($1) not found in directory <<<"
fi

set -e

# Do we really want to create a new domain?
confirm_yn "Create *new* domain ($1) ? "

msg_formatted "$i_step Committing LDIF Update ..."

printf "\
dn: dc=$1,ou=Domains,ou=Mail,dc=leuxner,dc=net\n\
dc: $1\n\
objectClass: dNSDomain\n\
objectClass: top\n" | ldapadd -ZZ -D $ldap_bind_dn -w $ldap_bind_dn_pw -H $ldap_server | while read input; do
        msg_formatted "$i_step $input"
done

msg_formatted "$i_done Virtual domain ($1) has been created <<<"
