#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"
echo ""; echo "${BOLD}Exercise 6 — Troubleshooting${RESET}"; echo ""

checkconf=$(ssh_server "sudo named-checkconf 2>&1; echo \$?")
assert_contains "named-checkconf passes" "$checkconf" "^0$"

zone_path=$(ssh_server "test -f /etc/bind/zones/db.lab.qlab && echo /etc/bind/zones/db.lab.qlab || echo /var/lib/bind/db.lab.qlab")
checkzone=$(ssh_server "sudo named-checkzone lab.qlab $zone_path 2>&1")
assert_contains "named-checkzone passes" "$checkzone" "OK"

logs=$(ssh_server "journalctl -u named --no-pager -n 5 2>/dev/null || journalctl -u bind9 --no-pager -n 5 2>/dev/null")
assert_contains "DNS logs are accessible" "$logs" "."

report_results "Exercise 6"
