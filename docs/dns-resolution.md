# DNS and Name Resolution (Week 2 Task 5)

## Public name: github.com
```
$ nslookup github.com
Server:		127.0.0.53
Address:	127.0.0.53#53

Non-authoritative answer:
Name:	github.com
Address: 135.235.149.144

$ dig github.com +noall +answer +stats
github.com.		27	IN	A	135.235.149.144
;; Query time: 1 msec
;; SERVER: 127.0.0.53#53(127.0.0.53) (UDP)

$ dig @49.45.0.3 github.com +short          # ask the upstream server directly, bypassing the local stub
135.235.149.144

$ resolvectl query github.com
github.com: 135.235.149.144                                 -- link: enp0s3
-- Information acquired via protocol DNS in 9.0ms.
```
- The server that answered is **127.0.0.53** - the local `systemd-resolved` stub on loopback, not
  a server on the network.
- "Non-authoritative" = the answer came from a resolver/cache, not from GitHub's own DNS servers.
- `27` in the `dig` answer is the TTL in seconds: how long the answer may be cached. `1 msec`
  means it was served from the cache.
- A name that does not exist:
  ```
  $ nslookup does-not-exist.github.com
  *** Can't find does-not-exist.github.com: No answer
  ```

## Where the VM's resolver configuration comes from
```
$ grep -v '^#' /etc/resolv.conf
nameserver 127.0.0.53
options edns0 trust-ad
search .

$ resolvectl dns
Global:
Link 2 (enp0s3): 49.45.0.3 fd17:625c:f037:2::3

$ grep hosts /etc/nsswitch.conf
hosts:          files mdns4_minimal [NOTFOUND=return] dns
```
Order of lookup for a name (from `nsswitch.conf`):
1. **files** = `/etc/hosts`
2. **mdns4_minimal** = multicast DNS for `*.local` names. `[NOTFOUND=return]` means: if a `.local`
   name is not found by mDNS, **stop - do not ask DNS**.
3. **dns** = `systemd-resolved` on 127.0.0.53, which forwards to `49.45.0.3` (received by DHCP from
   the VirtualBox NAT, i.e. the Windows host's DNS server).

## Local mapping: retail.local
```
$ cat /etc/hosts
127.0.0.1 localhost
127.0.1.1 Lokesh-Ubuntu
::1     ip6-localhost ip6-loopback
...
$ getent hosts retail.local || echo 'retail.local: no answer'
retail.local: no answer (exit 2)
$ curl -sS http://retail.local:8080/
curl: (6) Could not resolve host: retail.local
```
`curl: (6)` is a **name resolution** failure - no connection was even attempted. Compare with
`curl: (7)` (resolved fine, connection refused) in the other incidents.

Editing `/etc/hosts` needs root and I have no sudo in this session, so I first proved the mapping
with curl's own override, which skips name resolution and connects to the IP I give it:
```
$ curl -s -o /dev/null -w 'HTTP %{http_code} from %{remote_ip}:%{remote_port}\n' \
       --resolve retail.local:8080:10.0.2.15 http://retail.local:8080/
HTTP 200 from 10.0.2.15:8080
```

**To do with sudo** (temporary - remove the line afterwards):
```bash
echo '10.0.2.15 retail.local' | sudo tee -a /etc/hosts
getent hosts retail.local            # expect: 10.0.2.15  retail.local
curl -s -o /dev/null -w '%{http_code}\n' http://retail.local:8080/   # expect 200
sudo sed -i '/ retail.local$/d' /etc/hosts
```
This should work despite the mDNS rule because `files` comes **before** `mdns4_minimal`. A
`.local` name that is *not* in `/etc/hosts` never reaches DNS. Using `.local` for private names is
therefore a bad idea in general; `.internal` or `.test` are safer.

Note: a Windows browser does not read the VM's `/etc/hosts`. To use `retail.local` on Windows it
would go into `C:\Windows\System32\drivers\etc\hosts`, pointing at an address Windows can reach
(with NAT + port forward: `127.0.0.1`).

## The flow
```
Domain name                    github.com / retail.local / localhost
  |
  v
DNS / local resolver           1. /etc/hosts           (localhost, Lokesh-Ubuntu, retail.local)
  |                            2. mDNS for *.local      (avahi)
  |                            3. systemd-resolved 127.0.0.53 -> cache or upstream 49.45.0.3
  v
IP address                     135.235.149.144 / 10.0.2.15 / 127.0.0.1
  |
  v
Network connection             kernel picks route + interface (ip route get <ip>),
                               opens TCP to <ip>:<port>  (e.g. 10.0.2.15:8080)
```
DNS only turns a name into an IP. Once you have the IP, DNS plays no further part. So when a URL
fails, first check: did the name resolve (`getent hosts`, `curl` error 6), and only then look at
the connection.
