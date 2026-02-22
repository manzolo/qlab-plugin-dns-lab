# DNS Lab — Step-by-Step Guide

This guide walks you through **DNS (Domain Name System)**, the "phone book" of the internet. DNS translates human-readable domain names (like `web.lab.qlab`) into IP addresses that computers use to communicate.

By the end of this lab you will understand how DNS works, query different record types, manage forward and reverse zones, and troubleshoot DNS issues.

## Prerequisites

```bash
qlab run dns-lab
```

Open **two terminals**:

```bash
# Terminal 1 — DNS Server
qlab shell dns-lab-server

# Terminal 2 — DNS Client
qlab shell dns-lab-client
```

Wait for cloud-init on both:

```bash
cloud-init status --wait
```

## Network Topology

```
        Host Machine
       ┌────────────┐
       │  SSH :auto │──────► dns-lab-server
       │  SSH :auto │──────► dns-lab-client
       │  DNS :auto │──────► dns-lab-server (53/udp+tcp)
       └────────────┘

   Internal LAN (192.168.100.0/24)
  ┌──────────────────────────────────────┐
  │  ┌──────────────┐ ┌──────────────┐  │
  │  │ dns-server   │ │ dns-client   │  │
  │  │ 192.168.100.1│ │ DHCP         │  │
  │  │ BIND9        │ │ dnsmasq      │  │
  │  └──────────────┘ └──────────────┘  │
  └──────────────────────────────────────┘
```

## Credentials

- **Username:** `labuser` / **Password:** `labpass` (both VMs)

## Pre-configured DNS Records (zone: lab.qlab)

| Record | Type | Value |
|--------|------|-------|
| ns1.lab.qlab | A | 10.20.30.1 |
| web.lab.qlab | A | 10.20.30.10 |
| mail.lab.qlab | A | 10.20.30.20 |
| db.lab.qlab | A | 10.20.30.30 |
| app.lab.qlab | A | 10.20.30.40 |
| web.lab.qlab | AAAA | fd00::10 |
| www.lab.qlab | CNAME | web.lab.qlab |
| ftp.lab.qlab | CNAME | web.lab.qlab |
| lab.qlab | MX | mail.lab.qlab (pri 10) |
| lab.qlab | TXT | SPF, DMARC |

---

## Exercise 01 — DNS Anatomy

**VM:** dns-lab-server
**Goal:** Understand how BIND9 is configured.

DNS is hierarchical: root servers → TLD servers (.com, .org) → authoritative servers (your domain). BIND9 is the most widely used DNS server software. It can act as authoritative (answering for zones it owns), recursive (resolving queries by asking other servers), or both.

### 1.1 Check BIND9 is running

```bash
systemctl status named 2>/dev/null || systemctl status bind9
```

### 1.2 Explore configuration

```bash
ls /etc/bind/
cat /etc/bind/named.conf.local
```

### 1.3 List zone files

```bash
ls /etc/bind/zones/ 2>/dev/null || ls /var/lib/bind/
```

### 1.4 Read the forward zone file

```bash
cat /etc/bind/zones/db.lab.qlab 2>/dev/null || cat /var/lib/bind/db.lab.qlab
```

Notice the SOA (Start of Authority) record, NS records, and the various A/CNAME/MX records.

**Verification:** BIND9 is running and zone files contain DNS records.

---

## Exercise 02 — Querying DNS Records

**VM:** dns-lab-client
**Goal:** Use `dig` to query different DNS record types.

`dig` (Domain Information Groper) is the standard tool for DNS queries. Unlike `nslookup`, it shows the full DNS response including all sections.

### 2.1 Query an A record

```bash
dig @192.168.100.1 web.lab.qlab
```

**Expected answer section:**
```
web.lab.qlab.    ...    IN    A    10.20.30.10
```

### 2.2 Query with +short

```bash
dig @192.168.100.1 web.lab.qlab +short
```

**Expected output:** `10.20.30.10`

### 2.3 Query different record types

```bash
dig @192.168.100.1 web.lab.qlab AAAA +short
dig @192.168.100.1 www.lab.qlab CNAME +short
dig @192.168.100.1 lab.qlab MX +short
dig @192.168.100.1 lab.qlab TXT +short
```

### 2.4 Use nslookup

```bash
nslookup web.lab.qlab 192.168.100.1
```

### 2.5 Query SRV records

```bash
dig @192.168.100.1 _http._tcp.lab.qlab SRV +short
```

**Verification:** All record types resolve correctly from the client.

---

## Exercise 03 — Forward Zone Management

**VM:** dns-lab-server
**Goal:** Add a new record to the forward zone.

Zone files follow a specific format. The serial number in the SOA record must be incremented every time you make a change — secondary DNS servers use it to detect updates.

### 3.1 Backup the zone file

```bash
sudo cp /etc/bind/zones/db.lab.qlab /etc/bind/zones/db.lab.qlab.bak 2>/dev/null || sudo cp /var/lib/bind/db.lab.qlab /var/lib/bind/db.lab.qlab.bak
```

### 3.2 Add a new A record

Edit the zone file and add:
```
test    IN  A   10.20.30.99
```

Remember to **increment the serial number** in the SOA record.

### 3.3 Validate the zone

```bash
sudo named-checkzone lab.qlab /etc/bind/zones/db.lab.qlab 2>/dev/null || sudo named-checkzone lab.qlab /var/lib/bind/db.lab.qlab
```

**Expected output:**
```
zone lab.qlab/IN: loaded serial ...
OK
```

### 3.4 Reload BIND9

```bash
sudo rndc reload 2>/dev/null || sudo systemctl reload bind9
```

### 3.5 Verify from client

On **dns-lab-client**:
```bash
dig @192.168.100.1 test.lab.qlab +short
```

**Expected output:** `10.20.30.99`

### 3.6 Restore backup

```bash
sudo cp /etc/bind/zones/db.lab.qlab.bak /etc/bind/zones/db.lab.qlab 2>/dev/null || sudo cp /var/lib/bind/db.lab.qlab.bak /var/lib/bind/db.lab.qlab
sudo rndc reload 2>/dev/null || sudo systemctl reload bind9
```

**Verification:** New record resolves after zone reload.

---

## Exercise 04 — Reverse DNS

**VM:** dns-lab-client (queries), dns-lab-server (zone files)
**Goal:** Understand reverse DNS (IP → hostname).

Reverse DNS maps IP addresses back to hostnames. It uses the special `in-addr.arpa` domain with octets reversed. For example, 10.20.30.10 becomes `10.30.20.10.in-addr.arpa`.

### 4.1 Query reverse DNS

```bash
dig @192.168.100.1 -x 10.20.30.10 +short
```

**Expected output:** `web.lab.qlab.`

### 4.2 Read the reverse zone file

On **dns-lab-server**:
```bash
cat /etc/bind/zones/db.10.20.30 2>/dev/null || cat /var/lib/bind/db.10.20.30
```

### 4.3 Understand PTR records

PTR records map IP → hostname. The zone `30.20.10.in-addr.arpa` handles reverse lookups for 10.20.30.0/24.

**Verification:** Reverse DNS lookup returns the correct hostname.

---

## Exercise 05 — DNS Resolution Chain

**VM:** dns-lab-client
**Goal:** Understand how recursive resolution works.

### 5.1 Resolve an external domain

```bash
dig google.com +short
```

### 5.2 Check dnsmasq forwarding

```bash
cat /etc/dnsmasq.conf | grep -v '^#' | grep -v '^$'
```

### 5.3 Query with trace

```bash
dig @192.168.100.1 web.lab.qlab +trace
```

### 5.4 Observe caching

```bash
dig @192.168.100.1 web.lab.qlab | grep "Query time"
dig @192.168.100.1 web.lab.qlab | grep "Query time"
```

The second query should be faster (cached).

**Verification:** External resolution works through forwarding.

---

## Exercise 06 — Troubleshooting

**VM:** dns-lab-server
**Goal:** Use diagnostic tools to find and fix DNS problems.

### 6.1 Validate configuration

```bash
sudo named-checkconf
```

### 6.2 Validate zone files

```bash
sudo named-checkzone lab.qlab /etc/bind/zones/db.lab.qlab 2>/dev/null || sudo named-checkzone lab.qlab /var/lib/bind/db.lab.qlab
```

### 6.3 Check BIND9 logs

```bash
journalctl -u named --no-pager -n 20 2>/dev/null || journalctl -u bind9 --no-pager -n 20
```

### 6.4 Check rndc status

```bash
sudo rndc status 2>/dev/null
```

**Verification:** Config and zone validation tools work, logs are accessible.

---

## Troubleshooting

### BIND9 won't start
```bash
sudo named-checkconf
journalctl -u named --no-pager -n 30
```

### Record not resolving
```bash
# Check zone file syntax
sudo named-checkzone lab.qlab /etc/bind/zones/db.lab.qlab
# Did you increment the serial?
# Did you reload? sudo rndc reload
```

### Client can't reach server
```bash
ping 192.168.100.1
dig @192.168.100.1 web.lab.qlab
```

### Packages not installed
```bash
cloud-init status --wait
```
