# Networking — condensed baseline

A deliberately narrow slice for a SWE / data-eng bar. Ignore network-engineer
certification territory (routing protocols config, VLANs/STP, wireless security,
mobile/Bluetooth, QoS internals). The Boot.dev HTTP trio covers most of the
"must understand deeply" list organically.

## Must understand deeply
- HTTP/HTTPS (Boot.dev covers this)
- SSL/TLS handshake, conceptually (certificates, what it achieves)
- DNS resolution chain (browser cache → OS cache → resolver → root → TLD → authoritative)
- TCP vs UDP (reliable/ordered/handshake vs fire-and-forget)
- OSI 7 layers — one sentence each (Please Do Not Throw Sausage Pizza Away)
- TCP/IP 4-layer model and how it maps to OSI
- IP address, port, socket — what each is
- Public vs private IP, NAT conceptually
- CIDR notation (also helps with IP-to-CIDR style problems)
- Router vs switch (L3/IP vs L2/MAC)
- Load balancing: Round Robin, Least Connections

## Understand conceptually
- Firewall basics (packet filtering, stateful inspection)
- VPN conceptually (tunnel, encryption)
- LAN vs WAN vs VPC
- Symmetric vs asymmetric encryption; certificate authority
- SSH **key-auth model** (public/private keypair, what the handshake proves, why no
  password crosses the wire) — promoted from "just a term" because it's the most
  concrete instance of asymmetric crypto, reinforcing the green-tier crypto node.
  SSH *protocol internals* (cipher-suite negotiation, channel multiplexing, binary
  packet protocol) stay out of scope (network-engineer territory).
- BGP exists and routes between ISPs

## Just know the term exists
- DHCP (auto IP assignment), ARP (IP→MAC),
  SMTP/IMAP (email), FTP/SFTP (file transfer), NTP (time sync),
  Wireshark (packet capture)
  (SSH moved up to "understand conceptually" — see above.)

## One-afternoon resource
Cloudflare Learning Center articles on DNS, TLS, and TCP/IP. Pair with the Boot.dev
trio and the baseline is solid without touching cert material.
