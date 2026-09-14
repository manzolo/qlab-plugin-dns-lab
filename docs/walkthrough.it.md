---
kicker: QLab · dns-lab
title: |
  Una zona tua,
  risposta sul filo
subtitle: >
  BIND9 che serve una zona diretta e una inversa, e un client che risolve
  attraverso di lui sulla LAN del laboratorio. Ogni blocco qui sotto è stato
  catturato a lab acceso — compresa la query stessa, vista partire dal client e
  arrivare al server.
facts:
  - [Comando, "`qlab run dns-lab`"]
  - [VM, "`dns-lab-server` 10.20.30.1 · `dns-lab-client` 10.20.30.50"]
  - [Zone, "`lab.qlab` diretta · `30.20.10.in-addr.arpa` inversa"]
  - [Esito, "`qlab test dns-lab` → 7 esercizi, tutti superati"]
---

## 1. Le due macchine, e l'indirizzo che non è finto

{{evidence:topology}}

La LAN del laboratorio è `10.20.30.0/24`, e non è una scelta arbitraria: è la
sottorete che il file di zona stesso dichiara. `ns1.lab.qlab` è definito come
`10.20.30.1`, e il server risponde davvero su `10.20.30.1`. Il record è quindi
vero e non decorativo — si può risolvere `ns1.lab.qlab` e poi pingare il
risultato, raggiungendo la macchina che ha dato la risposta.

Ogni VM porta anche la scheda SLIRP di QEMU per `qlab shell`. Due interfacce su
una macchina DNS sono esattamente la situazione in cui «su quale indirizzo sta
ascoltando il mio server» smette di essere una domanda retorica.

## 2. Di cosa il server è autoritativo

{{evidence:zones}}

Due zone: dai nomi agli indirizzi, e dagli indirizzi ai nomi. Sono file separati
con numeri di serie separati, e a tenerli d'accordo non c'è nulla se non voi —
per questo su reti vere una risoluzione inversa così spesso contraddice quella
diretta.

{{evidence:zonefile}}

Tutto quello che un principiante incontra, in un posto solo: il `SOA` con i suoi
tempi, `NS`, `A` e `AAAA`, gli alias `CNAME`, gli `MX` con le priorità, i `TXT`
che trasportano le policy SPF e DMARC, e gli `SRV` che pubblicizzano un servizio
con la sua porta.

{{evidence:named-status as=shell}}

`named-checkconf` e `named-checkzone` sono i due comandi da ricordare: BIND si
rifiuta di caricare una zona con un errore di sintassi e continua a servire la
precedente, quindi «ho modificato il file e non è cambiato niente» è quasi
sempre una zona che non è mai stata caricata.

## 3. Una query che attraversa la rete

Il client chiede; `tcpdump` sul server la guarda arrivare.

{{evidence:query-on-the-wire}}

La cattura è tutta la lezione. Una query parte da `10.20.30.50` da una porta
alta casuale, arriva su `10.20.30.1` porta 53, e la risposta torna indietro
subito. Il `+` dopo l'id della query significa che è stata chiesta ricorsione; l'
`*` nella risposta significa che il server è **autoritativo** per quel nome —
non è andato a chiedere a nessun altro, semplicemente lo sa.

L'ultima riga è la risoluzione inversa, e mostra il trucco di in-addr.arpa: per
chiedere di `10.20.30.10` si interroga il nome `10.30.20.10.in-addr.arpa`, con
gli ottetti rovesciati, perché il DNS delega da destra mentre gli indirizzi si
scrivono partendo dalla parte più significativa.

## 4. I tipi di record, visti dal client

{{evidence:record-types as=shell}}

`MX` restituisce due host con priorità — vince il numero più basso, e `mail2` a
20 è la riserva. `SRV` porta con sé una porta, ed è così che un client trova un
servizio senza che nessuno abbia scritto `:80` da qualche parte. `CNAME`
restituisce un altro *nome*, non un indirizzo, quindi il resolver deve fare un
altro giro.

## 5. Il dominio di ricerca, che si comporta diversamente in ogni strumento

{{evidence:search-domain as=shell}}

Qui ci si inciampa di continuo. `dig` ignora `search` di `/etc/resolv.conf` se
non gli si passa `+search`; `host` e `nslookup` lo applicano. Quindi `dig www`
che non restituisce niente mentre `host www` funziona non è un server rotto —
sono due strumenti con impostazioni predefinite diverse.

:::note Come risolve il client
{{evidence:resolv-client}}
Il client punta a sé stesso, e un `dnsmasq` locale inoltra tutto a
`10.20.30.1`. È una piccola cache davanti al server autoritativo, ed è come sono
organizzate quasi tutte le reti vere.
:::

## 6. Verifica

{{evidence:qlab-test grep="Exercise [0-9]+:|Exercises |All exercises" as=shell}}

L'esercizio 7 è quello che controlla la rete: gli esercizi da 1 a 6 interrogano
il server *dal server* con `@localhost`, e passerebbero anche se le due macchine
non riuscissero affatto a raggiungersi.

## 7. Cosa portarsi via

- Diretta e inversa sono due zone indipendenti. Non c'è niente che le sincronizzi.
- Una risposta autoritativa (`*` in una cattura, `aa` in un `dig` completo)
  significa che il server sa, non che ha chiesto a monte. È la differenza fra
  servire una zona ed essere un resolver.
- `in-addr.arpa` rovescia gli ottetti perché il DNS delega da destra.
- `dig` non usa la search list se non glielo si dice. `host` sì.
- Se una modifica sembra non avere effetto, si lanci `named-checkzone`: BIND
  continua a servire l'ultima zona caricata senza errori.

`guide.md` del plugin va oltre: aggiungere record e incrementare il seriale,
la delega inversa, e leggere una catena di risoluzione con `+trace`.
