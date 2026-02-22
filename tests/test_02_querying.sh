#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"
echo ""; echo "${BOLD}Exercise 2 — Querying DNS Records${RESET}"; echo ""

# Query from server (using localhost) since internal LAN may not route
a_record=$(ssh_server "dig @localhost web.lab.qlab +short 2>/dev/null")
assert_contains "A record resolves" "$a_record" "10.20.30.10"

aaaa_record=$(ssh_server "dig @localhost web.lab.qlab AAAA +short 2>/dev/null")
assert_contains "AAAA record resolves" "$aaaa_record" "2001:db8::10|fd00::10"

cname_record=$(ssh_server "dig @localhost www.lab.qlab CNAME +short 2>/dev/null")
assert_contains "CNAME record resolves" "$cname_record" "web.lab.qlab"

mx_record=$(ssh_server "dig @localhost lab.qlab MX +short 2>/dev/null")
assert_contains "MX record resolves" "$mx_record" "mail.lab.qlab"

txt_record=$(ssh_server "dig @localhost lab.qlab TXT +short 2>/dev/null")
assert_contains "TXT record resolves" "$txt_record" "v=spf1|spf"

ns_record=$(ssh_server "dig @localhost lab.qlab NS +short 2>/dev/null")
assert_contains "NS record resolves" "$ns_record" "ns1.lab.qlab"

report_results "Exercise 2"
