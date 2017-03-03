#!/bin/sh
set -e
# Create new user in Dovecot 2.x passwd-file
# Thomas Leuxner <tlx@leuxner.net> 20-01-2013

# no trailing slashes here:
domain_passwd_root='/var/vmail/auth.d'
domain_vmail_root='/var/vmail/domains'
passwd_file=passwd
passwd_output_permissions='doveauth:dovecot'
vmail_unix_uid=5000
vmail_unix_gid=5000
user_quota='userdb_quota_rule=*:storage=5G'
if [ $# -eq 0 ]; then
    echo "usage: $0 user@domain" >&2
    exit 1
fi

msg_formatted() {
  echo "[>] $*"
}

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
doveadm user $1 && { printf '\nUser already exists.\n' >&2; exit 1; }

# Split out domain part from $1 user@domain
local_part=${1%@*}
domain_part=${1#*@}

# Do we really want to create a new user?
confirm_yn "Create *new* user \"$1\" ? "

# Read SSHA password for user from input
password_hash=$(doveadm pw -s SSHA512)

# Create passwd-file
passwd_user="$1:$password_hash:$vmail_unix_uid:$vmail_unix_gid::$domain_vmail_root/$domain_part/$local_part::$user_quota"
passwd_output_dir=$domain_passwd_root/$domain_part
passwd_output_file=$passwd_output_dir/$passwd_file
[ -d $passwd_output_dir ] || { echo 'Creating domain directory.'; mkdir -m 500 $passwd_output_dir; }
[ -f $passwd_output_file ] || { echo 'Creating domain passwd-file.'; touch $passwd_output_file; }
msg_formatted 'Writing passwd-file user entry'
echo $passwd_user >> $passwd_output_file
chown -R $passwd_output_permissions $passwd_output_dir
chmod 400 $passwd_output_file

grep $1 $passwd_output_dir/$passwd_file
echo '[ Complete ]'
