# dns-lab — DNS & BIND9 Lab

[![QLab Plugin](https://img.shields.io/badge/QLab-Plugin-blue)](https://github.com/manzolo/qlab)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Linux-lightgrey)](https://github.com/manzolo/qlab)

A [QLab](https://github.com/manzolo/qlab) plugin that creates two virtual machines for learning DNS concepts with BIND9: record types (A, AAAA, CNAME, MX, PTR, NS, TXT, SRV, SOA), zone management, reverse DNS, and query tools.

| VM | SSH Port | Packages | Purpose |
|----|----------|----------|---------|
| `dns-lab-server` | dynamic | `bind9`, `bind9-utils`, `dnsutils`, `net-tools` | DNS server running BIND9 with pre-configured zones |
| `dns-lab-client` | dynamic | `dnsutils`, `curl`, `whois`, `iputils-ping` | DNS client for querying and exploring records |

### Pre-configured DNS Records (lab.qlab)

| Type | Name | Value | Purpose |
|------|------|-------|---------|
| SOA | `lab.qlab` | `ns1.lab.qlab. admin.lab.qlab.` | Start of authority |
| NS | `lab.qlab` | `ns1.lab.qlab.` | Nameserver |
| A | `ns1.lab.qlab.` | `10.20.30.1` | DNS server |
| A | `web.lab.qlab.` | `10.20.30.10` | Web server |
| A | `mail.lab.qlab.` | `10.20.30.20` | Mail server |
| A | `db.lab.qlab.` | `10.20.30.30` | Database server |
| A | `app.lab.qlab.` | `10.20.30.40` | Application server |
| AAAA | `web.lab.qlab.` | `2001:db8::10` | IPv6 web server |
| CNAME | `www.lab.qlab.` | `web.lab.qlab.` | Alias for web |
| CNAME | `ftp.lab.qlab.` | `web.lab.qlab.` | Another alias |
| MX | `lab.qlab.` | `10 mail.lab.qlab.` | Primary mail (priority 10) |
| MX | `lab.qlab.` | `20 mail2.lab.qlab.` | Backup mail (priority 20) |
| TXT | `lab.qlab.` | `"v=spf1 mx -all"` | SPF record |
| TXT | `_dmarc.lab.qlab.` | `"v=DMARC1; p=reject"` | DMARC record |
| SRV | `_http._tcp.lab.qlab.` | `10 0 80 web.lab.qlab.` | HTTP service |
| SRV | `_mysql._tcp.lab.qlab.` | `10 0 3306 db.lab.qlab.` | MySQL service |
| PTR | `1.30.20.10.in-addr.arpa.` | `ns1.lab.qlab.` | Reverse DNS |
| PTR | `10.30.20.10.in-addr.arpa.` | `web.lab.qlab.` | Reverse DNS |
| PTR | `20.30.20.10.in-addr.arpa.` | `mail.lab.qlab.` | Reverse DNS |
| PTR | `30.30.20.10.in-addr.arpa.` | `db.lab.qlab.` | Reverse DNS |
| PTR | `40.30.20.10.in-addr.arpa.` | `app.lab.qlab.` | Reverse DNS |

## Architecture

```
┌──────────────────── Host ────────────────────────┐
│                                                  │
│  localhost:<DNS_PORT>  ── DNS port forwarding (UDP+TCP)│
│                                                  │
│  ┌─────────────────────────┐  ┌────────────────┐ │
│  │ dns-lab-server          │  │ dns-lab-client │ │
│  │  SSH: dynamic           │  │  SSH: dynamic  │ │
│  │                         │  │                │ │
│  │  BIND9 (:53)            │  │  dig           │ │
│  │  Zone: lab.qlab        │  │  nslookup      │ │
│  │  Zone: 30.20.10.arpa    │  │  host          │ │
│  │  named-checkzone        │  │  whois         │ │
│  └───────────┬─────────────┘  └──────┬─────────┘ │
│              │     10.0.2.2          │           │
│              └───────────────────────┘           │
│         client queries server via                │
│         dig @10.0.2.2 -p <DNS_PORT>                    │
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

> **Before starting:** Run `qlab ports` on the host to see the dynamically allocated ports. In the exercises below, replace `<DNS_PORT>` with the actual port shown by `qlab ports` for guest port 53.

## Exercise 1: Query Basic A and AAAA Records

**On the client VM:**

```bash
# Query the A record for web.lab.qlab
dig @10.0.2.2 -p <DNS_PORT> web.lab.qlab

# Query with short output
dig @10.0.2.2 -p <DNS_PORT> web.lab.qlab +short

# Query all A records
dig @10.0.2.2 -p <DNS_PORT> ns1.lab.qlab +short
dig @10.0.2.2 -p <DNS_PORT> mail.lab.qlab +short
dig @10.0.2.2 -p <DNS_PORT> db.lab.qlab +short
dig @10.0.2.2 -p <DNS_PORT> app.lab.qlab +short

# Query the AAAA (IPv6) record
dig @10.0.2.2 -p <DNS_PORT> web.lab.qlab AAAA
```

**Expected results:**
- `web.lab.qlab` → `10.20.30.10`
- `web.lab.qlab AAAA` → `2001:db8::10`

---

## Exercise 2: Explore CNAME Aliases

**On the client VM:**

```bash
# Query a CNAME record
dig @10.0.2.2 -p <DNS_PORT> www.lab.qlab

# Notice: the response includes both the CNAME and the resolved A record
dig @10.0.2.2 -p <DNS_PORT> www.lab.qlab +short

# Try another alias
dig @10.0.2.2 -p <DNS_PORT> ftp.lab.qlab

# Query specifically for CNAME type
dig @10.0.2.2 -p <DNS_PORT> www.lab.qlab CNAME
```

**Lesson:** CNAME records create aliases. When you query `www.lab.qlab`, DNS first resolves the CNAME to `web.lab.qlab`, then returns its A record.

---

## Exercise 3: Query MX Records (Mail Routing)

**On the client VM:**

```bash
# Query MX records for the domain
dig @10.0.2.2 -p <DNS_PORT> lab.qlab MX

# Observe the priority values (lower = higher priority)
# mail.lab.qlab has priority 10 (primary)
# mail2.lab.qlab has priority 20 (backup)
dig @10.0.2.2 -p <DNS_PORT> lab.qlab MX +short

# Verify the mail servers have A records
dig @10.0.2.2 -p <DNS_PORT> mail.lab.qlab +short
dig @10.0.2.2 -p <DNS_PORT> mail2.lab.qlab +short
```

**Lesson:** MX records direct email. Lower priority numbers indicate preferred servers. If `mail.lab.qlab` (priority 10) is down, email is routed to `mail2.lab.qlab` (priority 20).

---

## Exercise 4: Reverse DNS with PTR Records

**On the client VM:**

```bash
# Reverse lookup: IP → hostname
dig @10.0.2.2 -p <DNS_PORT> -x 10.20.30.10

# Short output
dig @10.0.2.2 -p <DNS_PORT> -x 10.20.30.10 +short

# Try all reverse lookups
dig @10.0.2.2 -p <DNS_PORT> -x 10.20.30.1 +short     # ns1
dig @10.0.2.2 -p <DNS_PORT> -x 10.20.30.20 +short    # mail
dig @10.0.2.2 -p <DNS_PORT> -x 10.20.30.30 +short    # db
dig @10.0.2.2 -p <DNS_PORT> -x 10.20.30.40 +short    # app
```

**Lesson:** PTR records map IP addresses back to hostnames. They are stored in a separate reverse zone (`30.20.10.in-addr.arpa`).

---

## Exercise 5: TXT Records (SPF and DMARC)

**On the client VM:**

```bash
# Query TXT records for the domain
dig @10.0.2.2 -p <DNS_PORT> lab.qlab TXT

# Query the DMARC record
dig @10.0.2.2 -p <DNS_PORT> _dmarc.lab.qlab TXT

# Short output
dig @10.0.2.2 -p <DNS_PORT> lab.qlab TXT +short
dig @10.0.2.2 -p <DNS_PORT> _dmarc.lab.qlab TXT +short
```

**Lesson:** TXT records store arbitrary text. Common uses include SPF (which servers can send email for a domain) and DMARC (email authentication policy). These are critical for email security and deliverability.

---

## Exercise 6: SRV Records (Service Discovery)

**On the client VM:**

```bash
# Query SRV records
dig @10.0.2.2 -p <DNS_PORT> _http._tcp.lab.qlab SRV
dig @10.0.2.2 -p <DNS_PORT> _mysql._tcp.lab.qlab SRV

# SRV format: priority weight port target
# 10 0 80 web.lab.qlab.  → HTTP on web:80
# 10 0 3306 db.lab.qlab.  → MySQL on db:3306
```

**Lesson:** SRV records advertise services, including the port and host. They follow the naming convention `_service._proto.domain`. This is how clients can discover services without hardcoding ports.

---

## Exercise 7: SOA and NS Records (Zone Authority)

**On the client VM:**

```bash
# Query the SOA record
dig @10.0.2.2 -p <DNS_PORT> lab.qlab SOA

# Query NS records
dig @10.0.2.2 -p <DNS_PORT> lab.qlab NS

# Query ANY to see all records for the domain
dig @10.0.2.2 -p <DNS_PORT> lab.qlab ANY
```

**Lesson:** The SOA record defines the authoritative information about a zone: the primary nameserver, admin email, serial number, and timing parameters. NS records declare which servers are authoritative for the zone.

---

## Exercise 8: Add a New DNS Record

**On the server VM:**

```bash
# View the current zone file
cat /etc/bind/zones/db.lab.qlab

# Add a new A record for "api.lab.qlab"
sudo bash -c 'cat >> /etc/bind/zones/db.lab.qlab << EOF

; Added by student
api     IN      A       10.20.30.50
EOF'

# IMPORTANT: Increment the serial number
sudo sed -i 's/2024010101/2024010102/' /etc/bind/zones/db.lab.qlab

# Validate the zone file
sudo named-checkzone lab.qlab /etc/bind/zones/db.lab.qlab

# Reload BIND9
sudo rndc reload
```

**On the client VM:**

```bash
# Verify the new record
dig @10.0.2.2 -p <DNS_PORT> api.lab.qlab +short
# Should return: 10.20.30.50
```

**Lesson:** When modifying zone files, always increment the serial number and validate with `named-checkzone` before reloading.

---

## Exercise 9: Alternative Query Tools (nslookup and host)

**On the client VM:**

```bash
# nslookup — interactive-style queries
nslookup -port=<DNS_PORT> web.lab.qlab 10.0.2.2
nslookup -port=<DNS_PORT> -type=MX lab.qlab 10.0.2.2
nslookup -port=<DNS_PORT> -type=TXT lab.qlab 10.0.2.2

# host — simpler output format
host -p <DNS_PORT> web.lab.qlab 10.0.2.2
host -p <DNS_PORT> -t MX lab.qlab 10.0.2.2
host -p <DNS_PORT> -t TXT lab.qlab 10.0.2.2
host -p <DNS_PORT> 10.20.30.10 10.0.2.2    # reverse lookup
```

**Lesson:** `dig` gives the most detailed output, `nslookup` is widely available across platforms, and `host` provides the simplest human-readable format.

---

## Exercise 10: Query Tracing and Advanced dig Options

**On the client VM:**

```bash
# Trace the full resolution path
dig @10.0.2.2 -p <DNS_PORT> web.lab.qlab +trace

# Short output (just the answer)
dig @10.0.2.2 -p <DNS_PORT> web.lab.qlab +short

# Show only the answer section
dig @10.0.2.2 -p <DNS_PORT> web.lab.qlab +noall +answer

# Query with specific options
dig @10.0.2.2 -p <DNS_PORT> web.lab.qlab +norecurse    # non-recursive query
dig @10.0.2.2 -p <DNS_PORT> web.lab.qlab +tcp           # force TCP instead of UDP
dig @10.0.2.2 -p <DNS_PORT> web.lab.qlab +stats         # show query statistics

# Check zone transfer (AXFR)
dig @10.0.2.2 -p <DNS_PORT> lab.qlab AXFR
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
