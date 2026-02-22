#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"
echo ""; echo "${BOLD}Exercise 4 — Reverse DNS${RESET}"; echo ""

ptr=$(ssh_server "dig @localhost -x 10.20.30.10 +short 2>/dev/null")
assert_contains "Reverse lookup for 10.20.30.10" "$ptr" "web.lab.qlab"

rev_zone=$(ssh_server "ls /etc/bind/zones/db.10.20.30 2>/dev/null || ls /var/lib/bind/db.10.20.30 2>/dev/null" || echo "")
assert_contains "Reverse zone file exists" "$rev_zone" "db.10.20.30"

report_results "Exercise 4"
