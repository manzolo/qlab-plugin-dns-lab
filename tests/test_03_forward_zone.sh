#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"
echo ""; echo "${BOLD}Exercise 3 — Forward Zone Management${RESET}"; echo ""

# Find zone file path
zone_path=$(ssh_server "test -f /etc/bind/zones/db.lab.qlab && echo /etc/bind/zones/db.lab.qlab || echo /var/lib/bind/db.lab.qlab")

# Backup zone file
ssh_server "sudo cp $zone_path ${zone_path}.test.bak" >/dev/null

# Add test record (increment serial)
ssh_server "sudo bash -c 'serial=\$(date +%Y%m%d%H); sed -i \"s/[0-9]\\{10\\}/\${serial}/\" $zone_path; echo \"newtest  IN  A  10.20.30.99\" | sudo tee -a $zone_path'" >/dev/null 2>&1

# Validate zone
check=$(ssh_server "sudo named-checkzone lab.qlab $zone_path 2>&1")
assert_contains "Zone validates after adding record" "$check" "OK"

# Reload
ssh_server "sudo rndc reload 2>/dev/null || sudo systemctl reload bind9" >/dev/null 2>&1 || true
sleep 2

# Verify the new record resolves
result=$(ssh_server "dig @localhost newtest.lab.qlab +short 2>/dev/null")
assert_contains "New record resolves" "$result" "10.20.30.99"

# Restore
ssh_server "sudo cp ${zone_path}.test.bak $zone_path; sudo rm -f ${zone_path}.test.bak; sudo rndc reload 2>/dev/null || sudo systemctl reload bind9" >/dev/null 2>&1 || true

report_results "Exercise 3"
