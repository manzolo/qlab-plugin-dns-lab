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

## Exercises

> **New to DNS?** See the [Step-by-Step Guide](guide.md) for complete walkthroughs with full examples and expected output.

| # | Exercise | What you'll do |
|---|----------|----------------|
| 1 | **DNS Anatomy** | Explore BIND9 installation, zone files, and configuration |
| 2 | **Querying DNS Records** | Use `dig` to query A, AAAA, CNAME, MX, TXT, SRV, PTR records |
| 3 | **Forward Zone Management** | Add new records, increment serial, reload zones |
| 4 | **Reverse DNS** | Query and manage PTR records for reverse lookups |
| 5 | **DNS Resolution Chain** | Trace queries and understand DNS delegation |
| 6 | **Troubleshooting** | Diagnose common DNS issues with dig, nslookup, host |

## Automated Tests

An automated test suite validates the exercises against running VMs:

```bash
# Start the lab first
qlab run dns-lab
# Wait ~90s for cloud-init, then run all tests
qlab test dns-lab
```

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
