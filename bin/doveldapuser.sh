#!/bin/sh
set -e
# Create new user in Dovecot using LDAP scheme:
# https://github.com/tleuxner/ldap-virtualMail
# Thomas Leuxner <tlx@leuxner.net> 01-11-2018
#
ldap_server='ldap://ldap.example.com/'
ldap_bind_dn='cn=admin,dc=example,dc=com'
ldap_bind_dn_pw='secret'
ldap_search_base='ou=Users,ou=Mail,dc=example,dc=com'
ldap_uid_prefix='vmail'
vmail_home_base="/var/vmail/domains"
vmail_unix_uid=5000
vmail_unix_gid=5000
user_quota='5G'

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
doveadm user -u $1 && { printf '\nUser already exists.\n' >&2; exit 1; }

# Split out domain part from $1 user@domain
local_part=${1%@*}
domain_part=${1#*@}

# Do we really want to create a new user?
confirm_yn "Create *new* user \"$1\" ? "

ldap_max_uid=$(ldapsearch -LLL -ZZ -D $ldap_bind_dn -w $ldap_bind_dn_pw -H $ldap_server -b $ldap_search_base objectClass=mailUser uid | awk '{if(max<$2){max=$2;uid=$2}}END{print uid}')
ldap_max_uid=$(echo $ldap_max_uid | sed -e "s/$ldap_uid_prefix//")
ldap_max_uid=$((ldap_max_uid+1))

msg_formatted "$i_start Creating new record ($ldap_uid_prefix$ldap_max_uid) <<<"

# Read password for user from input
password_hash=$(mkpasswd --rounds 5000 -m sha-512 --salt $(head -c 40 /dev/urandom | base64 | sed -e 's/+/./g' | cut -b 10-25))

msg_formatted "$i_step Committing LDIF Update ..."

printf "\
dn: uid=$ldap_uid_prefix$ldap_max_uid,$ldap_search_base\n\
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
userPassword: {CRYPT}$password_hash\n" | ldapadd -ZZ -D $ldap_bind_dn -w $ldap_bind_dn_pw -H $ldap_server

msg_formatted "$i_step Flushing negative user cache ..."
doveadm auth cache flush $1
msg_formatted "$i_done User has been created $date <<<"
