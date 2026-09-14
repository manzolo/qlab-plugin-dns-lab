---
kicker: QLab · dns-lab
title: |
  A zone you own,
  answered over the wire
subtitle: >
  BIND9 serving a forward and a reverse zone, and a client that resolves
  through it across the lab LAN. Every block below was captured from a running
  lab — including the query itself, seen leaving the client and arriving at the
  server.
facts:
  - [Command, "`qlab run dns-lab`"]
  - [VMs, "`dns-lab-server` 10.20.30.1 · `dns-lab-client` 10.20.30.50"]
  - [Zone, "`lab.qlab` forward · `30.20.10.in-addr.arpa` reverse"]
  - [Outcome, "`qlab test dns-lab` → 7 exercises, all passed"]
---

## 1. The two machines, and the address that is not a fiction

{{evidence:topology}}

The lab LAN is `10.20.30.0/24`, and that is not an arbitrary choice: it is the
subnet the zone file itself advertises. `ns1.lab.qlab` is declared as
`10.20.30.1`, and the server really answers on `10.20.30.1`. So the record is
true rather than decorative — you can resolve `ns1.lab.qlab` and then ping the
result, and reach the machine that gave you the answer.

Each VM also carries QEMU's SLIRP card for `qlab shell`. Two interfaces on a DNS
box is exactly the situation where "which address is my server listening on"
stops being a rhetorical question.

## 2. What the server is authoritative for

{{evidence:zones}}

Two zones: names to addresses, and addresses back to names. They are separate
files with separate serial numbers, and nothing keeps them in agreement except
you — which is why a reverse lookup so often disagrees with the forward one on
real networks.

{{evidence:zonefile}}

Everything a beginner meets in one place: `SOA` and its timers, `NS`, `A` and
`AAAA`, `CNAME` aliases, `MX` with priorities, `TXT` carrying SPF and DMARC
policy, and `SRV` advertising a service with its port.

{{evidence:named-status as=shell}}

`named-checkconf` and `named-checkzone` are the two commands worth remembering:
BIND will refuse to load a zone with a syntax error and keep serving the
previous one, so "I edited the file and nothing changed" is almost always a zone
that never loaded.

## 3. A query crossing the network

The client asks; `tcpdump` on the server watches it arrive.

{{evidence:query-on-the-wire}}

The capture is the whole lesson. A query leaves `10.20.30.50` from a random high
port, arrives at `10.20.30.1` port 53, and the answer comes straight back. The
`+` after the query id means recursion was requested; the `*` in the reply means
the server is **authoritative** for that name — it did not go and ask anyone
else, it simply knows.

The last line is the reverse lookup, and it shows the trick of in-addr.arpa: to
ask about `10.20.30.10` you query the name `10.30.20.10.in-addr.arpa`, with the
octets reversed, because DNS delegates from the right and addresses are written
most-significant-first.

## 4. Record types, from the client

{{evidence:record-types as=shell}}

`MX` returns two hosts with priorities — lower wins, and `mail2` at 20 is the
fallback. `SRV` carries a port, which is how a client finds a service without
anyone hardcoding `:80`. `CNAME` returns another *name*, not an address, so the
resolver has to go round again.

## 5. The search domain, which behaves differently in every tool

{{evidence:search-domain as=shell}}

This trips people up constantly. `dig` ignores `search` in `/etc/resolv.conf`
unless you pass `+search`; `host` and `nslookup` apply it. So `dig www` returning
nothing while `host www` works is not a broken server — it is two tools with
different defaults.

:::note How the client resolves
{{evidence:resolv-client}}
The client points at itself, and a local `dnsmasq` forwards everything to
`10.20.30.1`. That is a small cache in front of the authoritative server, which
is how most real networks are arranged.
:::

## 6. Verification

{{evidence:qlab-test grep="Exercise [0-9]+:|Exercises |All exercises" as=shell}}

Exercise 7 is the one that checks the network: exercises 1 to 6 query the server
*from the server* with `@localhost`, and would pass even if the two machines
could not reach each other at all.

## 7. What to take away

- Forward and reverse are two independent zones. Nothing synchronises them.
- An authoritative answer (`*` in a capture, `aa` in a full `dig`) means the
  server knows, rather than having asked upstream. It is the difference between
  serving a zone and being a resolver.
- `in-addr.arpa` reverses the octets because DNS delegates from the right.
- `dig` does not use the search list unless told to. `host` does.
- If an edit seems to have no effect, run `named-checkzone`: BIND keeps serving
  the last zone that loaded cleanly.

`guide.md` in the plugin goes further: adding records and bumping the serial,
reverse delegation, and reading a resolution chain with `+trace`.
