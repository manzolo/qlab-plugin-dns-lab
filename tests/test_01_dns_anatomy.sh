#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"
echo ""; echo "${BOLD}Exercise 1 — DNS Anatomy${RESET}"; echo ""

bind_status=$(ssh_server "systemctl is-active named 2>/dev/null || systemctl is-active bind9 2>/dev/null")
assert_contains "BIND9 is active" "$bind_status" "active"

assert "BIND config exists" ssh_server "test -f /etc/bind/named.conf.local"

zone_files=$(ssh_server "ls /etc/bind/zones/ 2>/dev/null || ls /var/lib/bind/ 2>/dev/null")
assert_contains "Forward zone file exists" "$zone_files" "db.lab.qlab"

assert "dig is installed on client" ssh_client "which dig"
assert "nslookup is installed on client" ssh_client "which nslookup"

report_results "Exercise 1"
