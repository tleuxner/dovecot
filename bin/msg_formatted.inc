# Message initials used in msg_formatted output
i_start='[+]'
i_step='[>]'
i_warn='[!]'
i_done='[C]'

msg_formatted() {
  echo "$(date "+%b %d %H:%M:%S") $*"
}
