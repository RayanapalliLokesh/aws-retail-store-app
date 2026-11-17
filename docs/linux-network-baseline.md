# Linux Network Baseline (Week 2 Task 1)

Machine: Ubuntu 26.04.1 LTS VM `Lokesh-Ubuntu`, VirtualBox (`systemd-detect-virt` -> `oracle`).
Captured 17-Nov-2026.

## Summary

| Item | Value | From |
|---|---|---|
| Loopback interface | `lo` | `ip addr` |
| Loopback IP | `127.0.0.1/8` (IPv6 `::1/128`) | `ip addr` |
| Primary network interface | `enp0s3` (MAC `08:00:27:f2:69:52` - VirtualBox range `08:00:27`) | `ip addr` |
| Ubuntu VM IP address | `10.0.2.15` | `ip addr`, `hostname -I` |
| Network prefix / subnet | `/24` -> network `10.0.2.0/24`, broadcast `10.0.2.255`, hosts `10.0.2.1 - 10.0.2.254` | `ip addr`, `ip route` |
| Default gateway | `10.0.2.2` | `ip route` |
| Default route | `default via 10.0.2.2 dev enp0s3 proto dhcp src 10.0.2.15 metric 100` | `ip route` |
| Interface used by the default route | `enp0s3` | `ip route` |
| How the address was assigned | DHCP (`dynamic`, `proto dhcp`, lease 80640 s) | `ip addr`, `ip route` |
| Other interface | `docker0` `172.17.0.1/16` (Docker bridge, internal to the VM) | `ip addr` |

`10.0.2.15` with gateway `10.0.2.2` is the standard address plan of **VirtualBox NAT mode**
(see `docs/vm-networking.md`).

## Evidence

```
$ ip -br addr
lo               UNKNOWN        127.0.0.1/8 ::1/128
enp0s3           UP             10.0.2.15/24 fd17:625c:f037:2:a00:27ff:fef2:6952/64 fe80::a00:27ff:fef2:6952/64
docker0          DOWN           172.17.0.1/16
```

```
$ ip addr
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
    inet6 ::1/128 scope host noprefixroute
2: enp0s3: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 08:00:27:f2:69:52 brd ff:ff:ff:ff:ff:ff
    inet 10.0.2.15/24 brd 10.0.2.255 scope global dynamic noprefixroute enp0s3
       valid_lft 80640sec preferred_lft 80640sec
    inet6 fd17:625c:f037:2:a00:27ff:fef2:6952/64 scope global dynamic noprefixroute
    inet6 fe80::a00:27ff:fef2:6952/64 scope link noprefixroute
3: docker0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue state DOWN group default
    link/ether ba:bc:80:e0:16:72 brd ff:ff:ff:ff:ff:ff
    inet 172.17.0.1/16 brd 172.17.255.255 scope global docker0
```

```
$ hostname -I
10.0.2.15 172.17.0.1 fd17:625c:f037:2:a00:27ff:fef2:6952
```
(`hostname -I` lists every address except loopback, including the Docker bridge - so "the VM IP"
is the one on the interface that has the default route, `enp0s3`.)

```
$ ip route
default via 10.0.2.2 dev enp0s3 proto dhcp src 10.0.2.15 metric 100
10.0.2.0/24 dev enp0s3 proto kernel scope link src 10.0.2.15 metric 100
172.17.0.0/16 dev docker0 proto kernel scope link src 172.17.0.1 linkdown

$ ip route get 8.8.8.8
8.8.8.8 via 10.0.2.2 dev enp0s3 src 10.0.2.15 uid 1000
```

## How to read the output
- `inet 10.0.2.15/24` - IPv4 address and prefix length. `/24` = the first 24 bits are the
  network, so every `10.0.2.x` is "on my link" and reachable without a router.
- `scope host` on `lo` - only valid inside this machine. `scope global` on `enp0s3` - usable on the network.
- `state UP` / `LOWER_UP` - interface is enabled and has a link. `docker0` is `DOWN`/`NO-CARRIER`
  when no container is running (it shows `linkdown` in the route table).
- `ip route get <ip>` asks the kernel which route, interface and source address it would really
  use for that destination - better than reading the table by eye.
