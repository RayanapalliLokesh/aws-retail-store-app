# Loopback, localhost and Bind Address (Week 2 Task 2)

UI port: **8080**. The UI accepts `--server.address=<ip>` (Spring Boot), so it can be run in
both binding modes with `./scripts/run-ui.sh 127.0.0.1` or `./scripts/run-ui.sh 0.0.0.0`.

## Loopback and localhost

```
$ ping -c 2 127.0.0.1
64 bytes from 127.0.0.1: icmp_seq=1 ttl=64 time=0.467 ms
64 bytes from 127.0.0.1: icmp_seq=2 ttl=64 time=0.029 ms
2 packets transmitted, 2 received, 0% packet loss

$ getent hosts localhost
::1             localhost
$ grep localhost /etc/hosts
127.0.0.1 localhost
::1     ip6-localhost ip6-loopback
```

- **What does localhost resolve to?** `127.0.0.1` (IPv4) and `::1` (IPv6). The answer comes from
  `/etc/hosts`, not from DNS - `nsswitch.conf` says `hosts: files ...`, so the file is read first.
- **Why does 127.0.0.1 always mean the current machine?** The whole `127.0.0.0/8` block is
  reserved for loopback. Packets to it go to the `lo` interface and never leave the kernel
  (`ip route get 127.0.0.1` -> `local 127.0.0.1 dev lo`). Every machine has its own `lo`.
- **Why can another laptop not use my 127.0.0.1?** On the other laptop, 127.0.0.1 is *that*
  laptop. It would be connecting to itself. I proved this with a container, which has its own
  network stack (like a separate machine):
  ```
  $ ./scripts/remote-client-test.sh 127.0.0.1 8080       # container connects to ITS 127.0.0.1
  bash: connect: Connection refused
  FAILED (exit 1)
  $ ./scripts/remote-client-test.sh 172.17.0.1 8080      # container connects to the VM
  HTTP/1.0 200 OK
  ```

## Test clients

| Client | How | Represents |
|---|---|---|
| Ubuntu, loopback | `curl http://127.0.0.1:8080/`, `http://localhost:8080/`, `http://[::1]:8080/` | same machine |
| Ubuntu, own LAN IP | `curl http://10.0.2.15:8080/` | same machine, but via the real interface address |
| Other machine | `scripts/remote-client-test.sh 172.17.0.1 8080` - a throw-away Docker container with its own network namespace, reaching the VM over `docker0` | "another machine" |
| Windows host | browser / `curl.exe` on Windows | **must be run by me on Windows - see below** |

## Mode A - `--server.address=0.0.0.0`

```
$ ss -lntp | grep ':8080 '
LISTEN 0      4096               *:8080             *:*    users:(("java",pid=23324,fd=37))
```
```
127.0.0.1  -> HTTP 200
localhost  -> HTTP 200
[::1]      -> HTTP 200
10.0.2.15  -> HTTP 200
container -> 172.17.0.1:8080 -> HTTP/1.0 200 OK
```

## Mode B - `--server.address=127.0.0.1`

```
$ ss -lntp | grep ':8080 '
LISTEN 0      4096   [::ffff:127.0.0.1]:8080             *:*    users:(("java",pid=25514,fd=37))
```
```
localhost  -> HTTP 200
10.0.2.15  -> curl: (7) Failed to connect to 10.0.2.15 port 8080 after 0 ms: Could not connect to server
container -> 172.17.0.1:8080 -> Connection refused
```

## Comparison

| Client | bind 0.0.0.0 | bind 127.0.0.1 |
|---|---|---|
| Ubuntu `127.0.0.1` / `localhost` | 200 | 200 |
| Ubuntu `10.0.2.15` (own LAN IP) | 200 | **refused** |
| Other machine (container via 172.17.0.1) | 200 | **refused** |
| Windows host | *to test* | *to test* - must fail |

## What I learned

- The bind address decides **on which local addresses the process accepts connections**:
  `127.0.0.1` = only connections that arrive on loopback; `0.0.0.0` = every IPv4 address of the
  machine (lo, enp0s3, docker0 ...).
- Even from the VM itself, `curl 10.0.2.15:8080` fails in mode B. The packet never leaves the
  machine, but it is addressed to 10.0.2.15, not to 127.0.0.1, so it does not match the socket.
- `ss` shows Java's 0.0.0.0 socket as `*:8080`. Java opened an IPv6 "any" socket that also accepts
  IPv4 (dual-stack); that is why `[::1]` also worked. With 127.0.0.1 it showed
  `[::ffff:127.0.0.1]:8080` - the IPv4 loopback written as an IPv4-mapped IPv6 address.
  Python's `http.server --bind 127.0.0.1` shows the plain form `127.0.0.1:9090`.
- Refused is immediate (`after 0 ms`). The kernel answers with a TCP reset because no socket matches.
  A firewall that DROPs would show a timeout instead - useful to tell the two apart.
- Security: anything that must not be reachable from outside should bind to 127.0.0.1 - which is
  why the Catalog DB is published on `127.0.0.1:3306` only.

## Windows host test (to run on Windows)

Not done yet - I cannot run commands on the Windows host from the VM. In **VirtualBox NAT mode**
I expect `http://10.0.2.15:8080` to fail from Windows **in both modes**, because Windows has no
route into the NAT network (see `docs/vm-networking.md`). With a NAT port-forward rule
(Host Port 8080 -> Guest Port 8080), `http://localhost:8080` on Windows should work in mode A
and fail in mode B.

```powershell
# PowerShell on Windows
Test-NetConnection 10.0.2.15 -Port 8080
Test-NetConnection 127.0.0.1 -Port 8080      # only meaningful with a port-forward rule
curl.exe -s -o NUL -w "%{http_code}`n" http://localhost:8080/
```
Results: _fill in after the test_.
