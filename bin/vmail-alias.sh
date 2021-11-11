#!/bin/sh
# Create new nail alias using LDAP scheme:
# https://github.com/tleuxner/ldap-virtualMail
# Thomas Leuxner <tlx@leuxner.net> 15-11-2018
#
# [16-11-2018]
# * moved LDAP binds to include
# * added check to verify hosted domains before adding aliases
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

# Split out domain part from $1 user@domain
local_part=${1%@*}
domain_part=${1#*@}

# Check for hosted domains. Don't add alias for non-existing domain
vmail_domain_hosted=$(postmap -q $domain_part ldap:/etc/postfix/ldap/virtual_domains.cf)

if [ "$vmail_domain_hosted" != "$domain_part" ]; then
  msg_formatted "$i_warn Virtual domain ($domain_part) not found in directory! <<<"
  exit 1
else
  msg_formatted "$i_start Virtual domain ($domain_part) found in directory <<<"
fi

set -e

# Is this alias already used?
vmail_alias_dn=$(ldapsearch -LLL -ZZ -D $ldap_bind_dn -w $ldap_bind_dn_pw -H $ldap_server -b $ldap_search_base "(&(objectClass=mailUser)(mailAlias=$1))" dn)
[ -z "$vmail_alias_dn" ] || { msg_formatted "$i_warn Virtual mail alias already in use by <$vmail_alias_dn>" >&2; exit 1; }

# Add alias to mail user
msg_formatted "$i_step Adding new alias ...\n"
read -p "Add to virtual mail user: " vmail_user
printf '\n'

# Do we have that mail user?
doveadm user -u $vmail_user || { printf '\n';msg_formatted "$i_warn No valid mail user found." >&2; exit 1; }
printf '\n'

# Fetch distinguished name of user record
vmail_user_dn=$(ldapsearch -LLL -ZZ -D $ldap_bind_dn -w $ldap_bind_dn_pw -H $ldap_server -b $ldap_search_base "(&(objectClass=mailUser)(mailDrop=$vmail_user))" dn)
msg_formatted "$i_step Selecting record ($vmail_user_dn) ...\n"

# Do we really want to create a new alias?
confirm_yn "Add new alias <$1> to ($vmail_user) ? "

# Update mailAlias for record
ldap_ldif_entry="$vmail_user_dn\nchangetype: modify\nadd: mailAlias\nmailAlias: $1"
msg_formatted "$i_step Committing LDIF update ..."
printf "$ldap_ldif_entry" | ldapmodify -n -ZZ -D $ldap_bind_dn -w $ldap_bind_dn_pw -H $ldap_server | while read input; do
        msg_formatted "$i_step $input"
done

msg_formatted "$i_done Alias has been created <<<"
