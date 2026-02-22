#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"
echo ""; echo "${BOLD}Exercise 5 — DNS Resolution Chain${RESET}"; echo ""

# Server can resolve local domain
local_query=$(ssh_server "dig @localhost web.lab.qlab +short 2>/dev/null")
assert_contains "Local domain resolves via server" "$local_query" "10.20.30.10"

# Multiple record types resolve
mail_query=$(ssh_server "dig @localhost mail.lab.qlab +short 2>/dev/null")
assert_contains "Mail record resolves" "$mail_query" "10.20.30.20"

# Query with trace shows resolution path
trace=$(ssh_server "dig @localhost web.lab.qlab +norecurse 2>/dev/null")
assert_contains "Non-recursive query returns answer" "$trace" "ANSWER"

report_results "Exercise 5"
