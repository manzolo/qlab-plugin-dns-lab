#!/usr/bin/env bash
# dns-lab install script

set -euo pipefail

echo ""
echo "  [dns-lab] Installing..."
echo ""
echo "  This plugin creates two VMs for learning DNS with BIND9:"
echo ""
echo "    1. dns-lab-server  — DNS Server VM"
echo "       Runs BIND9 with pre-configured zones"
echo "       Forward zone: lab.qlab (A, AAAA, CNAME, MX, TXT, SRV, NS, SOA)"
echo "       Reverse zone: 1.168.192.in-addr.arpa (PTR records)"
echo ""
echo "    2. dns-lab-client  — DNS Client VM"
echo "       Equipped with dig, nslookup, host, whois"
echo "       Query and explore the DNS server"
echo ""
echo "  What you will learn:"
echo "    - DNS record types: A, AAAA, CNAME, MX, PTR, NS, TXT, SRV, SOA"
echo "    - Forward and reverse zone management"
echo "    - BIND9 configuration and zone file syntax"
echo "    - DNS query tools: dig, nslookup, host"
echo "    - How to add and modify DNS records"
echo ""

# Create lab working directory
mkdir -p lab

# Check for required tools
echo "  Checking dependencies..."
local_ok=true
for cmd in qemu-system-x86_64 qemu-img genisoimage curl; do
    if command -v "$cmd" &>/dev/null; then
        echo "    [OK] $cmd"
    else
        echo "    [!!] $cmd — not found (install before running)"
        local_ok=false
    fi
done

if [[ "$local_ok" == true ]]; then
    echo ""
    echo "  All dependencies are available."
else
    echo ""
    echo "  Some dependencies are missing. Install them with:"
    echo "    sudo apt install qemu-kvm qemu-utils genisoimage curl"
fi

echo ""
echo "  [dns-lab] Installation complete."
echo "  Run with: qlab run dns-lab"
