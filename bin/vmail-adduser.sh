#!/bin/sh
# Create new user virtual mail user
# https://github.com/tleuxner/ldap-virtualMail
# Thomas Leuxner <tlx@leuxner.net> 01-11-2018
#
# [16-11-2018]
# * moved LDAP binds to include
# [11-11-2021]
# * renamed variables and prompts to refer to vmail users

vmail_uid_prefix='vmail'
vmail_home_base="/var/vmail/domains"
vmail_unix_uid=5000
vmail_unix_gid=5000
user_quota='5G'

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

# Check for hosted domains.
vmail_domain_hosted=$(postmap -q $domain_part ldap:/etc/postfix/ldap/virtual_domains.cf)

if [ "$vmail_domain_hosted" = "$domain_part" ]; then
  msg_formatted "$i_start Virtual domain ($domain_part) found in directory <<<\n"
else
  msg_formatted "$i_warn Virtual domain($domain_part) not found in directory! <<<"
  exit 1
fi

set -e

# Do we have that user?
doveadm user -u $1 && { printf '\n';msg_formatted "$i_warn Found existing user. Exiting! <<<" >&2; exit 1; }

# Is this alias already used?
vmail_alias_dn=$(ldapsearch -LLL -ZZ -D $ldap_bind_dn -w $ldap_bind_dn_pw -H $ldap_server -b $ldap_search_base "(&(objectClass=mailUser)(mailAlias=$1))" dn)
[ -z "$vmail_alias_dn" ] || { msg_formatted "$i_warn Virtual mail alias already in use by <$vmail_alias_dn>" >&2; exit 1; }

# Do we really want to create a new user?
printf '\n'
confirm_yn "Create *new* vmail user <$1> ? "

vmail_max_uid=$(ldapsearch -LLL -ZZ -D $ldap_bind_dn -w $ldap_bind_dn_pw -H $ldap_server -b $ldap_search_base objectClass=mailUser uid | awk '{if(max<$2){max=$2;uid=$2}}END{print uid}')
vmail_max_uid=$(echo $vmail_max_uid | sed -e "s/$vmail_uid_prefix//")
vmail_max_uid=$((vmail_max_uid+1))
vmail_user=$vmail_uid_prefix$vmail_max_uid

msg_formatted "$i_start Creating new user record ($vmail_user) <<<"

# Read password for user from input
password_hash=$(mkpasswd --rounds 5000 -m sha-512 --salt $(head -c 40 /dev/urandom | base64 | sed -e 's/+/./g' | cut -b 10-25))

msg_formatted "$i_step Committing LDIF update ..."

printf "\
dn: uid=$vmail_user,$ldap_search_base\n\
mailHomeDirectory: $vmail_home_base/$domain_part/$local_part\n\
mailAlias: $local_part@$domain_part\n\
mailDrop: $local_part@$domain_part\n\
objectClass: account\n\
objectClass: simpleSecurityObject\n\
objectClass: mailUser\n\
objectClass: top\n\
mailUidNumber: $vmail_unix_uid\n\
mailGidNumber: $vmail_unix_gid\n\
mailEnabled: TRUE\n\
mailQuota: $user_quota\n\
mailNamespaceDisable: yes\n\
userPassword: {CRYPT}$password_hash\n" | ldapadd -ZZ -D $ldap_bind_dn -w $ldap_bind_dn_pw -H $ldap_server | while read input; do
        msg_formatted "$i_step $input"
done

msg_formatted "$i_step Flushing negative user cache in backend ..."
doveadm auth cache flush $1 | while read input; do
        msg_formatted "$i_step $input"
done

msg_formatted "$i_done User ($vmail_user) has been added to database <<<"
