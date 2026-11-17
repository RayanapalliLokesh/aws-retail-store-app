# Week 2 Learning Log

## Networking concepts studied
IP address and prefix, interface, loopback, port, bind address (127.0.0.1 vs 0.0.0.0), route table
and longest-prefix match, default gateway, ARP, DNS resolution order (`/etc/hosts` -> mDNS -> DNS),
VirtualBox NAT vs bridged vs host-only, "connection refused" vs "timeout" vs "cannot resolve".

## Commands used
`ip addr / route / route get / neigh`, `hostname -I`, `ss -lntp`, `lsof -i`, `ping`, `tracepath`,
`curl -w` / `--resolve`, `nslookup`, `dig`, `getent hosts`, `resolvectl`, `systemd-detect-virt`,
`/proc/<pid>/environ`. Details in `docs/command-notes.md`.

## What I implemented
- Closed the Week 1 backlog: UI runs directly on Ubuntu (Spring Boot jar), Catalog and its DB too; process, PID, port and logs documented; health and topology endpoints checked.
- Secrets check: scanned all history - no keys, tokens or real passwords; `.env`/`*.pem`/`id_*` are ignored; the DB password exists only as an environment variable.
- `scripts/run-ui.sh <bind> <port> <catalog-url>` to switch bind address and catalog endpoint easily.
- `scripts/remote-client-test.sh` - a container as a "second machine" for reachability tests.
- Docs: network baseline, bind-address experiment, listening sockets, VM networking, DNS, network flow / routing, UI-Catalog connectivity, Network Architecture V1 (+ PNG), connectivity runbook, command notes.

## What I intentionally broke
| Incident | Break |
|---|---|
| 04 | second Catalog on port 8081 (and python on 8080) -> `address already in use` |
| 05 | UI bound to 127.0.0.1 -> localhost works, remote refused |
| 06-A | Catalog stopped |
| 06-B | UI pointed at Catalog port 9999 |
| 06-C | UI pointed at hostname `catalog` (only valid inside docker-compose) |
| 06-D | UI catalog endpoint empty -> silent mock fallback |

## Initial hypothesis
- 05: for "remote fails" the first idea is usually "firewall" or "NAT". The evidence said bind
  address: `ss` showed `[::ffff:127.0.0.1]:8080` and the error was an instant *refused*, not a timeout.
- 06-D: the shop looked completely normal, so without topology I would have said "Catalog is fine".

## Evidence collected
In every incident file: the `curl` error type, `ss -lntp` lines, process environment from `/proc`,
UI exception (`ConnectException`, `UnknownHostException`), Catalog access log (silent or not), topology status.

## Actual root cause
- 04: two processes configured for the same port.
- 05: UI listening on loopback only.
- 06: A - dependency process down; B - wrong port in config; C - DNS name that does not exist outside Docker; D - missing endpoint, mock used.

## How I fixed it
Free port for the second instance (04), rebind to 0.0.0.0 (05), correct endpoint `http://localhost:8081` and Catalog restarted (06). Each fix validated with curl, `ss`, topology and `health_check.py`.

## Still open / not verified (needs the Windows host or sudo)
- The Windows -> VM test itself: VirtualBox adapter mode and port-forward rule, `Test-NetConnection` from PowerShell.
- `sudo ufw status verbose` - ufw is active, but its rules are not visible without sudo.
- Adding `retail.local` to `/etc/hosts` (tested with `curl --resolve` instead).

## Concepts still unclear
<!-- Lokesh: fill in in your own words -->

## Questions for mentor
<!-- Lokesh: fill in. Possible points from this week:
     - Should the UI's readiness check fail when a configured dependency is down, so a load balancer stops sending traffic?
     - Is it OK that Catalog listens on *:8081 (all addresses), or should internal services bind to 127.0.0.1 / a private network? -->
