# Ports and Listening Sockets (Week 2 Task 3)

Captured on 17-Nov-2026 with `ss -lntp` (TCP) and `ss -lnup` (UDP), with UI, Catalog and the
Catalog DB running. Columns without a process name belong to processes owned by another user
(root / systemd); listing them needs `sudo ss -lntp`, which I do not have on this VM.

## TCP listeners

| Process | PID | Bind address | Port | Protocol | What it is |
|---|---|---|---|---|---|
| java (Retail UI) | 25822 | `*` (all IPv4 + IPv6) | 8080 | TCP | Retail Store UI |
| catalog | 23907 | `*` | 8081 | TCP | Retail Store Catalog |
| docker-proxy (root) | - | 127.0.0.1 | 3306 | TCP | Catalog DB, published from the `catalog-db` container |
| systemd-resolved (root) | - | 127.0.0.53%lo | 53 | TCP/UDP | local DNS stub resolver |
| systemd-resolved (root) | - | 127.0.0.54 | 53 | TCP/UDP | resolver "proxy" stub |
| cupsd (root) | - | 127.0.0.1, [::1] | 631 | TCP | printing service |
| code (VS Code) | 12978, 9046 | 127.0.0.1 | 21833, 35389 | TCP | editor internals |
| claude | 14866 | 127.0.0.1 | 43035 | TCP | Claude Code helper (VS Code extension) |
| chronyd (root) | - | 127.0.0.1, [::1] | 323 | UDP | time sync control port |
| avahi (root) | - | 0.0.0.0, [::] | 5353 | UDP | mDNS (`.local` names) |

```
$ ss -lntp
State  Recv-Q Send-Q Local Address:Port  Peer Address:PortProcess
LISTEN 0      4096      127.0.0.54:53         0.0.0.0:*
LISTEN 0      511        127.0.0.1:21833      0.0.0.0:*    users:(("code",pid=12978,fd=61))
LISTEN 0      512        127.0.0.1:43035      0.0.0.0:*    users:(("claude",pid=14866,fd=14))
LISTEN 0      511        127.0.0.1:35389      0.0.0.0:*    users:(("code",pid=9046,fd=44))
LISTEN 0      4096       127.0.0.1:3306       0.0.0.0:*
LISTEN 0      4096   127.0.0.53%lo:53         0.0.0.0:*
LISTEN 0      4096       127.0.0.1:631        0.0.0.0:*
LISTEN 0      4096               *:8081             *:*    users:(("catalog",pid=23907,fd=6))
LISTEN 0      4096               *:8080             *:*    users:(("java",pid=25822,fd=37))
LISTEN 0      4096           [::1]:631           [::]:*
```
The owners of the root sockets were confirmed from the process list instead:
```
$ pgrep -a -x docker-proxy
22968 /usr/bin/docker-proxy -proto tcp -host-ip 127.0.0.1 -host-port 3306 -container-ip 172.17.0.2 -container-port 3306 -use-listen-fd
$ pgrep -a -x cupsd; pgrep -a -x chronyd; pgrep -a -x avahi-daemon
5488 /usr/sbin/cupsd -l
5249 /usr/sbin/chronyd -n -F 1
5102 avahi-daemon: running [Lokesh-Ubuntu.local]
$ systemctl is-active systemd-resolved
active
```

Flags: `-l` listening only, `-n` numbers (no name lookups), `-t` TCP, `-u` UDP, `-p` show process.

`lsof` gives the same answer from the process side:
```
$ lsof -nP -iTCP:8081 -sTCP:LISTEN
COMMAND   PID   USER FD   TYPE DEVICE SIZE/OFF NODE NAME
catalog 23907 lokesh 6u  IPv6 100002      0t0  TCP *:8081 (LISTEN)
```

## Why one machine can host many network applications

A listening socket is identified by **(protocol, local IP, local port)**. The kernel delivers an
incoming connection to the socket whose IP and port match the packet's destination. So:
- different ports = different applications (UI 8080, Catalog 8081, DB 3306), and
- even the **same port** can be used twice if the **IP** differs:

```
$ python3 -m http.server 9090 --bind 127.0.0.1 &  python3 -m http.server 9090 --bind 10.0.2.15 &
$ ss -lntp | grep ':9090 '
LISTEN 0      5          127.0.0.1:9090       0.0.0.0:*    users:(("python3",pid=26087,fd=3))
LISTEN 0      5          10.0.2.15:9090       0.0.0.0:*    users:(("python3",pid=26089,fd=3))

$ python3 -m http.server 9090 --bind 127.0.0.1     # third one, same IP AND port
OSError: [Errno 98] Address already in use
```
A socket on `*`/`0.0.0.0` covers every address, so nothing else can then use that port on any
address - that is the conflict in incident 04.

An established connection is identified by all four values (client IP, client port, server IP,
server port). That is how one server port talks to many clients at once:
```
$ ss -tnp state established '( sport = :8081 or dport = :8081 )'
Local Address:Port          Peer Address:Port
[::ffff:127.0.0.1]:8081     [::ffff:127.0.0.1]:41588   users:(("catalog",pid=23907,fd=8))
[::ffff:127.0.0.1]:41588    [::ffff:127.0.0.1]:8081    users:(("java",pid=25822,fd=40))
[::ffff:127.0.0.1]:8081     [::ffff:127.0.0.1]:55960   users:(("catalog",pid=23907,fd=7))
[::ffff:127.0.0.1]:55960    [::ffff:127.0.0.1]:8081    users:(("java",pid=25822,fd=39))
```
The UI (java) has two connections open to Catalog, from client ports 41588 and 55960.
