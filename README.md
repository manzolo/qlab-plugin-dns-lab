# dns-lab — DNS & BIND9 Lab

[![QLab Plugin](https://img.shields.io/badge/QLab-Plugin-blue)](https://github.com/manzolo/qlab)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Walkthrough](https://img.shields.io/badge/walkthrough-EN%20%26%20IT-informational)](docs/walkthrough-en.pdf)

A two-VM [QLab](https://github.com/manzolo/qlab) lab on a private LAN — a BIND9 server
serving a real forward and reverse zone, and a client with `dig` / `nslookup` / `host` —
for learning record types, zone management and how a lookup is actually answered.

## Quick start

```bash
qlab install dns-lab
qlab run dns-lab             # boots 2 VMs (~90s)
qlab shell dns-lab-server    # BIND9, zone lab.qlab — labuser / labpass
qlab shell dns-lab-client    # dig / nslookup / host — labuser / labpass
qlab test dns-lab            # run the automated checks
qlab stop dns-lab
```

The DNS port is forwarded to the host too — query it with `dig @127.0.0.1 -p <port> …`
(find the port with `qlab ports`).

## What's inside

| # | Exercise | What you do |
|---|----------|-------------|
| 1 | DNS anatomy | BIND9 install, zone files, configuration |
| 2 | Querying records | `dig` for A, AAAA, CNAME, MX, TXT, SRV, PTR |
| 3 | Forward zone | add records, bump the serial, reload |
| 4 | Reverse DNS | manage PTR records for reverse lookups |
| 5 | Resolution chain | trace queries and delegation |
| 6 | Troubleshooting | diagnose with dig / nslookup / host |

## Network

Private LAN `10.20.30.0/24`, isolated between the two VMs.

| VM | Address | Role |
|----|---------|------|
| `dns-lab-server` | `10.20.30.1` | BIND9, forward zone `lab.qlab` + reverse zone |
| `dns-lab-client` | `10.20.30.50` | query tools |

SSH: `labuser` / `labpass`, dynamically forwarded — see `qlab ports`.

## Learn more

- 📖 **[Step-by-step guide](guide.md)** — every exercise with full commands
- 📄 **Illustrated walkthrough** — a real run, captured live: **[English](docs/walkthrough-en.pdf)** · **[Italiano](docs/walkthrough-it.pdf)**
- 🧩 **[QLab](https://github.com/manzolo/qlab)** — the plugin runner: how install, overlays and cloud-init work
