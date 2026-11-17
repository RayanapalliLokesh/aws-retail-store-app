# VM Networking (Week 2 Task 4)

My setup: Windows laptop -> VirtualBox -> Ubuntu VM. From inside the VM the adapter mode is
**NAT** (evidence below). The VirtualBox settings window itself is on the Windows side, and I
still have to confirm it there.

## Evidence from inside the VM
```
$ systemd-detect-virt
oracle                                    <- VirtualBox
$ ip -br addr show enp0s3
enp0s3   UP   10.0.2.15/24                <- VirtualBox NAT default guest address
$ ip route | head -1
default via 10.0.2.2 dev enp0s3 proto dhcp src 10.0.2.15
$ ip neigh show dev enp0s3
10.0.2.2 lladdr 52:54:00:12:35:00 REACHABLE      <- the NAT engine's virtual router
$ resolvectl dns
Link 2 (enp0s3): 49.45.0.3 fd17:625c:f037:2::3   <- DNS handed out by the NAT DHCP (the host's DNS)
$ tracepath -n -m 6 1.1.1.1
 1:  10.0.2.2                                              0.751ms
 2:  10.0.2.2                                              2.552ms reached
```
`tracepath` "reaches" 1.1.1.1 at 10.0.2.2. VirtualBox NAT does not forward packets hop by hop -
it re-sends them from the Windows host's own network stack - so every router behind it is
invisible from the VM.

## The three modes

| | NAT (my current mode) | Bridged | Host-only |
|---|---|---|---|
| VM address | private, from VirtualBox (10.0.2.15) | from the home router, same subnet as the laptop (e.g. 192.168.1.x) | from the VirtualBox host-only network (default 192.168.56.x) |
| VM -> Internet | yes, through the NAT engine on the host | yes, directly through the home router | no (unless a second adapter is added) |
| Windows -> VM | **no direct route**; only through **port-forward rules** (host port -> guest port) | yes, at the VM's LAN IP | yes, at the host-only IP |
| Other device on home network -> VM | no (only via a port-forward bound to the laptop's LAN IP) | yes, the VM is a normal device on the LAN | no |
| Typical use | safe default, Internet only | VM acts as a real server on the LAN | private lab between host and VM |

## Answers

- **How is Ubuntu getting Internet access?** Packets leave `enp0s3` to the default gateway
  `10.0.2.2`. That gateway is the VirtualBox NAT engine on Windows, which rewrites them to come from
  the Windows host and sends them out through the laptop's Wi-Fi/LAN. Replies go back the same way.
- **Can Windows directly reach Ubuntu?** Not at `10.0.2.15`. That network exists only between
  VirtualBox and this VM, and Windows has no route to it. Windows can reach a VM service only
  through a NAT **port-forward rule**, e.g. Host `127.0.0.1:8080` -> Guest `8080`, and then opens
  `http://localhost:8080` *on Windows*. *(To confirm on Windows: `Test-NetConnection 10.0.2.15 -Port 8080`
  should fail.)*
- **Can another device on the home network reach Ubuntu?** No. It would need a port-forward rule
  bound to the laptop's LAN IP (and the Windows firewall to allow it), or bridged mode.
- **What changes if I switch from NAT to bridged?**
  - The VM gets a new IP from the home router (DHCP), in the same subnet as the laptop. The
    default gateway becomes the home router, and DNS usually the router too.
  - Windows and other LAN devices can reach the VM directly at that IP - no port forwards.
  - The VM is now exposed to the whole LAN, so bind address and `ufw` rules matter much more.
  - Bridged mode can fail on some Wi-Fi adapters and on networks that allow one MAC per port.
  - Things that hard-code `10.0.2.15` (my notes, `/etc/hosts` entries) must be updated.

## What this means for "local works, remote fails"
Two independent conditions must both be true for Windows to open the UI:
1. the UI listens on a non-loopback address (`0.0.0.0`) - incident 05, and
2. the VM network mode lets Windows in: a port-forward rule (NAT), or bridged / host-only mode.
