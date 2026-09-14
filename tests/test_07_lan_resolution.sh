#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"
echo ""; echo "${BOLD}Exercise 7 — Resolution across the lab LAN${RESET}"; echo ""

# Exercises 1-6 all query the server from the server, with @localhost. They pass
# even if the two machines cannot reach each other at all. These check the thing
# a DNS lab is actually about: a client resolving a name through a server, over
# a network.

# 7.1 The link exists and both ends are on it
srv_addr=$(ssh_server "ip -br addr" 2>/dev/null || echo "")
assert_contains "Server holds $SERVER_LAN_IP on the lab LAN" "$srv_addr" "$SERVER_LAN_IP"
cli_addr=$(ssh_client "ip -br addr" 2>/dev/null || echo "")
assert_contains "Client holds $CLIENT_LAN_IP on the lab LAN" "$cli_addr" "$CLIENT_LAN_IP"
assert "Client can reach the server" ssh_client "ping -c2 -W3 $SERVER_LAN_IP"

# 7.2 The server answers on its LAN address, not only on loopback
lan_query=$(ssh_client "dig @$SERVER_LAN_IP web.lab.qlab +short 2>/dev/null" || echo "")
assert_contains "Server answers queries arriving over the LAN" "$lan_query" "10.20.30.10"

# 7.3 ns1.lab.qlab is the server. The zone says so; now it is true.
ns1=$(ssh_client "dig @$SERVER_LAN_IP ns1.lab.qlab +short 2>/dev/null" || echo "")
assert_contains "ns1.lab.qlab resolves to the server's real address" "$ns1" "^$SERVER_LAN_IP$"
assert "ns1.lab.qlab answers ping from the client" ssh_client "ping -c2 -W3 ns1.lab.qlab"

# 7.4 The client's own resolver path works end to end: no @server, no hints.
#     This is what was broken — the forwarder pointed at a hardcoded host port.
plain=$(ssh_client "dig web.lab.qlab +short 2>/dev/null" || echo "")
assert_contains "Client resolves with no @server (its own resolv.conf path)" "$plain" "10.20.30.10"
# dig ignores the search list unless asked (+search); host and nslookup use it.
# That difference trips people up constantly, so check both behaviours.
bare_short=$(ssh_client "dig www +short 2>/dev/null" || echo "")
assert_not_contains "Plain 'dig www' does NOT apply the search domain" "$bare_short" "10.20.30.10"
searched=$(ssh_client "dig +search www +short 2>/dev/null" || echo "")
assert_contains "'dig +search www' resolves through the search domain" "$searched" "10.20.30.10"
hosted=$(ssh_client "host www 2>/dev/null" || echo "")
assert_contains "'host www' applies the search domain on its own" "$hosted" "web.lab.qlab"

# 7.5 Reverse resolution over the LAN
rev=$(ssh_client "dig @$SERVER_LAN_IP -x 10.20.30.10 +short 2>/dev/null" || echo "")
assert_contains "Reverse lookup works from the client" "$rev" "web.lab.qlab"

# 7.6 The server is not resolving through a stub that no longer exists
resolv=$(ssh_server "cat /etc/resolv.conf" 2>/dev/null || echo "")
assert_not_contains "Server's resolv.conf does not point at the dead systemd-resolved stub" "$resolv" "127.0.0.53"
bare=$(ssh_server "dig web.lab.qlab +short 2>/dev/null" || echo "")
assert_contains "A bare 'dig name' works on the server too" "$bare" "10.20.30.10"

report_results "Exercise 7"
