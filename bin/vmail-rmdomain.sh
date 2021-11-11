#!/bin/sh
# Remove Mail Domain from LDAP scheme:
# https://github.com/tleuxner/ldap-virtualMail
# Thomas Leuxner <tlx@leuxner.net> 10-11-2021

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
  msg_formatted "$i_start Virtual Domain ($1) found in directory <<<"
else
  msg_formatted "$i_warn Virtual Domain ($1) not found in directory! <<<"
  exit 1
fi

set -e

# skip comment output with -LLL
vmail_domain_dn=$(ldapsearch -LLL -ZZ -D $ldap_bind_dn -w $ldap_bind_dn_pw -H $ldap_server  "(&(objectclass=dNSDomain)(dc=$1))" dn)
msg_formatted "$i_step Selecting record ($vmail_domain_dn) ..."

# remove distinguished name tag
vmail_domain_dn=${vmail_domain_dn#*dn: }

# Do we really want to create a new domain?
confirm_yn "Remove *existing* domain ($1) ? "

msg_formatted "$i_step Committing LDIF Update ..."

ldapdelete -v -ZZ -D $ldap_bind_dn -w $ldap_bind_dn_pw -H $ldap_server "$vmail_domain_dn" | while read input; do
        msg_formatted "$i_step $input"
done

msg_formatted "$i_done Domain ($1) has been removed <<<"
