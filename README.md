# dns-lab — DNS & BIND9 Lab

[![QLab Plugin](https://img.shields.io/badge/QLab-Plugin-blue)](https://github.com/manzolo/qlab)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Linux-lightgrey)](https://github.com/manzolo/qlab)

A [QLab](https://github.com/manzolo/qlab) plugin that creates two virtual machines for learning DNS concepts with BIND9: record types (A, AAAA, CNAME, MX, PTR, NS, TXT, SRV, SOA), zone management, reverse DNS, and query tools.

| VM | SSH Port | Packages | Purpose |
|----|----------|----------|---------|
| `dns-lab-server` | 2228 | `bind9`, `bind9-utils`, `dnsutils`, `net-tools` | DNS server running BIND9 with pre-configured zones |
| `dns-lab-client` | 2229 | `dnsutils`, `curl`, `whois`, `iputils-ping` | DNS client for querying and exploring records |

### Pre-configured DNS Records (lab.local)

| Type | Name | Value | Purpose |
|------|------|-------|---------|
| SOA | `lab.local` | `ns1.lab.local. admin.lab.local.` | Start of authority |
| NS | `lab.local` | `ns1.lab.local.` | Nameserver |
| A | `ns1.lab.local.` | `192.168.1.1` | DNS server |
| A | `web.lab.local.` | `192.168.1.10` | Web server |
| A | `mail.lab.local.` | `192.168.1.20` | Mail server |
| A | `db.lab.local.` | `192.168.1.30` | Database server |
| A | `app.lab.local.` | `192.168.1.40` | Application server |
| AAAA | `web.lab.local.` | `2001:db8::10` | IPv6 web server |
| CNAME | `www.lab.local.` | `web.lab.local.` | Alias for web |
| CNAME | `ftp.lab.local.` | `web.lab.local.` | Another alias |
| MX | `lab.local.` | `10 mail.lab.local.` | Primary mail (priority 10) |
| MX | `lab.local.` | `20 mail2.lab.local.` | Backup mail (priority 20) |
| TXT | `lab.local.` | `"v=spf1 mx -all"` | SPF record |
| TXT | `_dmarc.lab.local.` | `"v=DMARC1; p=reject"` | DMARC record |
| SRV | `_http._tcp.lab.local.` | `10 0 80 web.lab.local.` | HTTP service |
| SRV | `_mysql._tcp.lab.local.` | `10 0 3306 db.lab.local.` | MySQL service |
| PTR | `1.1.168.192.in-addr.arpa.` | `ns1.lab.local.` | Reverse DNS |
| PTR | `10.1.168.192.in-addr.arpa.` | `web.lab.local.` | Reverse DNS |
| PTR | `20.1.168.192.in-addr.arpa.` | `mail.lab.local.` | Reverse DNS |
| PTR | `30.1.168.192.in-addr.arpa.` | `db.lab.local.` | Reverse DNS |
| PTR | `40.1.168.192.in-addr.arpa.` | `app.lab.local.` | Reverse DNS |

## Architecture

```
┌──────────────────── Host ────────────────────────┐
│                                                  │
│  localhost:5354  ── DNS port forwarding (UDP+TCP) │
│                                                  │
│  ┌─────────────────────────┐  ┌────────────────┐ │
│  │ dns-lab-server          │  │ dns-lab-client │ │
│  │  SSH: 2228              │  │  SSH: 2229     │ │
│  │                         │  │                │ │
│  │  BIND9 (:53)            │  │  dig           │ │
│  │  Zone: lab.local        │  │  nslookup      │ │
│  │  Zone: 1.168.192.arpa   │  │  host          │ │
│  │  named-checkzone        │  │  whois         │ │
│  └───────────┬─────────────┘  └──────┬─────────┘ │
│              │     10.0.2.2          │           │
│              └───────────────────────┘           │
│         client queries server via                │
│         dig @10.0.2.2 -p 5354                    │
└──────────────────────────────────────────────────┘
```

## Quick Start

```bash
qlab init
qlab install dns-lab
qlab run dns-lab
# Wait ~90s for boot + package installation
qlab shell dns-lab-server    # connect to DNS server
qlab shell dns-lab-client    # connect to client
```

## Credentials

- **Username:** `labuser`
- **Password:** `labpass`

---

## Exercise 1: Query Basic A and AAAA Records

**On the client VM:**

```bash
# Query the A record for web.lab.local
dig @10.0.2.2 -p 5354 web.lab.local

# Query with short output
dig @10.0.2.2 -p 5354 web.lab.local +short

# Query all A records
dig @10.0.2.2 -p 5354 ns1.lab.local +short
dig @10.0.2.2 -p 5354 mail.lab.local +short
dig @10.0.2.2 -p 5354 db.lab.local +short
dig @10.0.2.2 -p 5354 app.lab.local +short

# Query the AAAA (IPv6) record
dig @10.0.2.2 -p 5354 web.lab.local AAAA
```

**Expected results:**
- `web.lab.local` → `192.168.1.10`
- `web.lab.local AAAA` → `2001:db8::10`

---

## Exercise 2: Explore CNAME Aliases

**On the client VM:**

```bash
# Query a CNAME record
dig @10.0.2.2 -p 5354 www.lab.local

# Notice: the response includes both the CNAME and the resolved A record
dig @10.0.2.2 -p 5354 www.lab.local +short

# Try another alias
dig @10.0.2.2 -p 5354 ftp.lab.local

# Query specifically for CNAME type
dig @10.0.2.2 -p 5354 www.lab.local CNAME
```

**Lesson:** CNAME records create aliases. When you query `www.lab.local`, DNS first resolves the CNAME to `web.lab.local`, then returns its A record.

---

## Exercise 3: Query MX Records (Mail Routing)

**On the client VM:**

```bash
# Query MX records for the domain
dig @10.0.2.2 -p 5354 lab.local MX

# Observe the priority values (lower = higher priority)
# mail.lab.local has priority 10 (primary)
# mail2.lab.local has priority 20 (backup)
dig @10.0.2.2 -p 5354 lab.local MX +short

# Verify the mail servers have A records
dig @10.0.2.2 -p 5354 mail.lab.local +short
dig @10.0.2.2 -p 5354 mail2.lab.local +short
```

**Lesson:** MX records direct email. Lower priority numbers indicate preferred servers. If `mail.lab.local` (priority 10) is down, email is routed to `mail2.lab.local` (priority 20).

---

## Exercise 4: Reverse DNS with PTR Records

**On the client VM:**

```bash
# Reverse lookup: IP → hostname
dig @10.0.2.2 -p 5354 -x 192.168.1.10

# Short output
dig @10.0.2.2 -p 5354 -x 192.168.1.10 +short

# Try all reverse lookups
dig @10.0.2.2 -p 5354 -x 192.168.1.1 +short     # ns1
dig @10.0.2.2 -p 5354 -x 192.168.1.20 +short    # mail
dig @10.0.2.2 -p 5354 -x 192.168.1.30 +short    # db
dig @10.0.2.2 -p 5354 -x 192.168.1.40 +short    # app
```

**Lesson:** PTR records map IP addresses back to hostnames. They are stored in a separate reverse zone (`1.168.192.in-addr.arpa`).

---

## Exercise 5: TXT Records (SPF and DMARC)

**On the client VM:**

```bash
# Query TXT records for the domain
dig @10.0.2.2 -p 5354 lab.local TXT

# Query the DMARC record
dig @10.0.2.2 -p 5354 _dmarc.lab.local TXT

# Short output
dig @10.0.2.2 -p 5354 lab.local TXT +short
dig @10.0.2.2 -p 5354 _dmarc.lab.local TXT +short
```

**Lesson:** TXT records store arbitrary text. Common uses include SPF (which servers can send email for a domain) and DMARC (email authentication policy). These are critical for email security and deliverability.

---

## Exercise 6: SRV Records (Service Discovery)

**On the client VM:**

```bash
# Query SRV records
dig @10.0.2.2 -p 5354 _http._tcp.lab.local SRV
dig @10.0.2.2 -p 5354 _mysql._tcp.lab.local SRV

# SRV format: priority weight port target
# 10 0 80 web.lab.local.  → HTTP on web:80
# 10 0 3306 db.lab.local.  → MySQL on db:3306
```

**Lesson:** SRV records advertise services, including the port and host. They follow the naming convention `_service._proto.domain`. This is how clients can discover services without hardcoding ports.

---

## Exercise 7: SOA and NS Records (Zone Authority)

**On the client VM:**

```bash
# Query the SOA record
dig @10.0.2.2 -p 5354 lab.local SOA

# Query NS records
dig @10.0.2.2 -p 5354 lab.local NS

# Query ANY to see all records for the domain
dig @10.0.2.2 -p 5354 lab.local ANY
```

**Lesson:** The SOA record defines the authoritative information about a zone: the primary nameserver, admin email, serial number, and timing parameters. NS records declare which servers are authoritative for the zone.

---

## Exercise 8: Add a New DNS Record

**On the server VM:**

```bash
# View the current zone file
cat /etc/bind/zones/db.lab.local

# Add a new A record for "api.lab.local"
sudo bash -c 'cat >> /etc/bind/zones/db.lab.local << EOF

; Added by student
api     IN      A       192.168.1.50
EOF'

# IMPORTANT: Increment the serial number
sudo sed -i 's/2024010101/2024010102/' /etc/bind/zones/db.lab.local

# Validate the zone file
sudo named-checkzone lab.local /etc/bind/zones/db.lab.local

# Reload BIND9
sudo rndc reload
```

**On the client VM:**

```bash
# Verify the new record
dig @10.0.2.2 -p 5354 api.lab.local +short
# Should return: 192.168.1.50
```

**Lesson:** When modifying zone files, always increment the serial number and validate with `named-checkzone` before reloading.

---

## Exercise 9: Alternative Query Tools (nslookup and host)

**On the client VM:**

```bash
# nslookup — interactive-style queries
nslookup -port=5354 web.lab.local 10.0.2.2
nslookup -port=5354 -type=MX lab.local 10.0.2.2
nslookup -port=5354 -type=TXT lab.local 10.0.2.2

# host — simpler output format
host -p 5354 web.lab.local 10.0.2.2
host -p 5354 -t MX lab.local 10.0.2.2
host -p 5354 -t TXT lab.local 10.0.2.2
host -p 5354 192.168.1.10 10.0.2.2    # reverse lookup
```

**Lesson:** `dig` gives the most detailed output, `nslookup` is widely available across platforms, and `host` provides the simplest human-readable format.

---

## Exercise 10: Query Tracing and Advanced dig Options

**On the client VM:**

```bash
# Trace the full resolution path
dig @10.0.2.2 -p 5354 web.lab.local +trace

# Short output (just the answer)
dig @10.0.2.2 -p 5354 web.lab.local +short

# Show only the answer section
dig @10.0.2.2 -p 5354 web.lab.local +noall +answer

# Query with specific options
dig @10.0.2.2 -p 5354 web.lab.local +norecurse    # non-recursive query
dig @10.0.2.2 -p 5354 web.lab.local +tcp           # force TCP instead of UDP
dig @10.0.2.2 -p 5354 web.lab.local +stats         # show query statistics

# Check zone transfer (AXFR)
dig @10.0.2.2 -p 5354 lab.local AXFR
```

**Lesson:** `dig` has many options for controlling output and query behavior. `+trace` shows the full delegation chain, `+short` is great for scripting, and `+tcp` forces TCP for large responses.

---

## Managing VMs

```bash
qlab status                    # show all running VMs
qlab stop dns-lab              # stop both VMs
qlab stop dns-lab-server       # stop only server VM
qlab stop dns-lab-client       # stop only client VM
qlab log dns-lab-server        # view server VM boot log
qlab log dns-lab-client        # view client VM boot log
qlab uninstall dns-lab         # stop all VMs and remove plugin
```

## Reset

To start the lab from scratch:

```bash
qlab stop dns-lab
qlab run dns-lab
```

This recreates the overlay disks and cloud-init configuration, giving you a fresh environment.

## License

MIT
