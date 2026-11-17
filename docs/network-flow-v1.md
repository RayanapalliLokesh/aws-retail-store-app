# Network Flow V1 - Routing (Week 2 Task 6)

## Route table
```
$ ip route
default via 10.0.2.2 dev enp0s3 proto dhcp src 10.0.2.15 metric 100
10.0.2.0/24 dev enp0s3 proto kernel scope link src 10.0.2.15 metric 100
172.17.0.0/16 dev docker0 proto kernel scope link src 172.17.0.1
```

| | Route | Meaning |
|---|---|---|
| **Local route** | `10.0.2.0/24 dev enp0s3 scope link` | Every 10.0.2.x is on the same link. Send directly, no router. Created by the kernel (`proto kernel`) when the address was added |
| Local route (Docker) | `172.17.0.0/16 dev docker0` | Containers on the Docker bridge |
| Loopback (not shown by `ip route`; it is in the `local` table, `ip route show table local`) | `127.0.0.0/8 dev lo` | Never leaves the machine |
| **Default route** | `default via 10.0.2.2 dev enp0s3` | Everything that matches nothing more specific |
| **Gateway** | `10.0.2.2` | VirtualBox NAT engine |
| **Network interface** | `enp0s3` (source address 10.0.2.15) | |

## What the kernel actually chooses
```
$ ip route get 10.0.2.2          # the gateway itself - on the local subnet
10.0.2.2 dev enp0s3 src 10.0.2.15
$ ip route get 10.0.2.99         # any address on the local subnet - direct, no "via"
10.0.2.99 dev enp0s3 src 10.0.2.15
$ ip route get 172.17.0.5        # a container
172.17.0.5 dev docker0 src 172.17.0.1
$ ip route get 140.82.112.3      # outside every local subnet -> default route
140.82.112.3 via 10.0.2.2 dev enp0s3 src 10.0.2.15
$ ip route get 127.0.0.1
local 127.0.0.1 dev lo src 127.0.0.1
```
The word **`via`** appears only when a router (gateway) is needed.

The `local` routing table holds the machine's own addresses. It is checked first:
```
$ ip route show table local | grep -E '127|10.0.2'
local 10.0.2.15 dev enp0s3 proto kernel scope host src 10.0.2.15
broadcast 10.0.2.255 dev enp0s3 proto kernel scope link src 10.0.2.15
local 127.0.0.0/8 dev lo proto kernel scope host src 127.0.0.1
local 127.0.0.1 dev lo proto kernel scope host src 127.0.0.1
broadcast 127.255.255.255 dev lo proto kernel scope link src 127.0.0.1
```
So `curl http://10.0.2.15:8080` from the VM itself never goes out on the wire either - it is
delivered locally. It still fails when the UI is bound to 127.0.0.1, because the destination
address (10.0.2.15) does not match the socket (incident 05).

## What happens when the destination is outside the local subnet
Example: `curl https://github.com` -> 135.235.149.144.
1. **Longest prefix match.** The kernel compares the destination with every route and takes the
   most specific one that matches. 135.235.149.144 is not in 10.0.2.0/24 or 172.17.0.0/16, so only
   `default` (0.0.0.0/0) matches.
2. The route says `via 10.0.2.2 dev enp0s3`. The IP packet keeps **destination 135.235.149.144**,
   but it is sent in an Ethernet frame to the **gateway's MAC address**.
3. ARP finds the gateway MAC (cached in the neighbour table):
   ```
   $ ip neigh show dev enp0s3
   10.0.2.2 lladdr 52:54:00:12:35:00 REACHABLE
   $ ping -c 2 10.0.2.2
   64 bytes from 10.0.2.2: icmp_seq=1 ttl=64 time=0.570 ms
   ```
4. The gateway (VirtualBox NAT) forwards it on: Windows -> home router -> ISP -> Internet.
   Replies come back to 10.0.2.2, which delivers them to 10.0.2.15.

For a destination **inside** the subnet (10.0.2.x) step 2 is different: the frame goes straight
to the destination's own MAC, with no gateway involved.

If there were no default route, `ip route get 140.82.112.3` would answer `RTNETLINK answers:
Network is unreachable` and curl would fail immediately with "Network is unreachable" - a routing failure.

## Request flows on this VM (V1)

| Flow | Path | Route used |
|---|---|---|
| Ubuntu `curl localhost:8080` -> UI | lo -> UI socket `*:8080` | local table (`lo`) |
| UI -> Catalog `http://localhost:8081` | lo -> Catalog socket `*:8081` | `lo` |
| Catalog -> DB `127.0.0.1:3306` | lo -> docker-proxy -> docker0 -> 172.17.0.2:3306 | `lo`, then `172.17.0.0/16 dev docker0` |
| Container client -> UI `172.17.0.1:8080` | docker0 -> UI socket | container's default route -> 172.17.0.1 |
| VM -> github.com | enp0s3 -> 10.0.2.2 -> Internet | `default` |
| Windows -> UI | Windows -> NAT port-forward -> 10.0.2.15:8080 | needs the forward rule (see `vm-networking.md`) |
