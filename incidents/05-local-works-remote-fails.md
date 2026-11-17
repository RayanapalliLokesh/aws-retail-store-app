# Incident 05 - Localhost Works, Remote Access Fails

| | |
|---|---|
| Date | 17-Nov-2026, 11:16:23 - 11:16:55 UTC (lab) |
| Service | UI (port 8080) |
| Trigger | Intentional: UI restarted with `--server.address=127.0.0.1` |
| "Remote" client used | a Docker container (own network namespace) connecting to the VM at `172.17.0.1`, standing in for the Windows host. **The real Windows-side checks are listed at the end and still have to be run by me on Windows.** |

## Symptom
```
$ curl -s -o /dev/null -w 'from Ubuntu  localhost -> HTTP %{http_code}\n' http://localhost:8080/
from Ubuntu  localhost -> HTTP 200
$ ./scripts/remote-client-test.sh 172.17.0.1 8080
bash: connect: Connection refused
FAILED (exit 1)
```

## Investigation - layer by layer, in the order of the brief

**1. Application health** - healthy, so not an application failure:
```
$ curl -s http://127.0.0.1:8080/actuator/health
{"status":"UP"}
```

**2. Process exists**
```
$ ps -o pid,etime,comm -p 25514
    PID     ELAPSED COMMAND
  25514       00:09 java
```

**3. Port is listening** - yes, 8080:
```
$ ss -lntp | grep ':8080 '
LISTEN 0      4096   [::ffff:127.0.0.1]:8080             *:*    users:(("java",pid=25514,fd=37))
```

**4. Bind address** - **only loopback** (`[::ffff:127.0.0.1]` = 127.0.0.1). The command line confirms it:
```
$ tr '\0' ' ' < /proc/25514/cmdline
java -jar /home/lokesh/aws-retail-store-app/app/src/ui/target/ui-0.0.1-SNAPSHOT.jar --server.address=127.0.0.1 --server.port=8080
$ curl -sS http://10.0.2.15:8080/
curl: (7) Failed to connect to 10.0.2.15 port 8080 after 0 ms: Could not connect to server
```
Even the VM itself cannot connect through its own LAN address. This is already enough to explain
the failure, but I continue to check the remaining layers so I don't miss a second problem.

**5. Ubuntu VM IP**
```
$ ip -4 -br addr show enp0s3
enp0s3           UP             10.0.2.15/24
```

**6. VM networking mode** - VirtualBox, NAT (10.0.2.15 + gateway 10.0.2.2 is the VirtualBox NAT
plan, MAC prefix 08:00:27 is VirtualBox):
```
$ systemd-detect-virt
oracle
$ ip route | head -2
default via 10.0.2.2 dev enp0s3 proto dhcp src 10.0.2.15 metric 100
10.0.2.0/24 dev enp0s3 proto kernel scope link src 10.0.2.15 metric 100
```
Consequence: even with a correct bind, Windows cannot reach `10.0.2.15` directly in NAT mode.
It needs a NAT port-forward rule (see `docs/vm-networking.md`). **This is a second, independent
layer for the real Windows case.**

**7. Host-to-VM reachability** - is the VM reachable at all from the "remote" client? Test another
port that *is* bound to all addresses (Catalog `*:8081`):
```
$ docker run --rm mariadb:10.9 bash -c 'timeout 3 bash -c "exec 3<>/dev/tcp/172.17.0.1/8081" && echo TCP-8081-OPEN'
TCP-8081-OPEN
```
The path to the VM works; only port 8080 is refused. So it is not routing.

**8. Firewall rules**
```
$ systemctl is-active ufw
active
$ sudo -n ufw status
sudo: interactive authentication is required
```
ufw is active, but I cannot read its rules without sudo. Two facts show the firewall is **not**
the cause here: the 8080 failure is an immediate **connection refused** (a TCP reset from the
kernel because no socket matches - a DROP rule would cause a timeout), and 8081 on the same path
works. **To do on my side:** `sudo ufw status verbose` - if it says `deny (incoming)` without an
`8080/tcp ALLOW` rule, it will block Windows -> 8080 even after the bind is fixed.

## Root cause
The UI was bound to `127.0.0.1`, so it accepted only connections that arrive on the loopback
interface. Requests to the VM's address (10.0.2.15 / 172.17.0.1) found no matching socket and were
refused. Application, process, port, IP and routing were all fine.

## Resolution
```
$ ./scripts/run-ui.sh 0.0.0.0 8080
ui started, PID 25822, bind 0.0.0.0:8080, catalog 'http://localhost:8081', log /home/lokesh/retail-logs/ui.log
```

## Validation (9)
```
$ ss -lntp | grep ':8080 '
LISTEN 0      4096               *:8080             *:*    users:(("java",pid=25822,fd=37))
$ curl -s -o /dev/null -w 'via VM IP 10.0.2.15 -> HTTP %{http_code}\n' http://10.0.2.15:8080/
via VM IP 10.0.2.15 -> HTTP 200
$ ./scripts/remote-client-test.sh 172.17.0.1 8080
HTTP/1.0 200 OK
Catalog | HEALTHY | Endpoint | http://localhost:8081        (UI /topology)
```

## Still to verify from the Windows host (cannot be done from inside the VM)
1. In VirtualBox: *Settings -> Network -> Adapter 1* - note "Attached to" (expected: NAT).
2. If NAT: *Advanced -> Port Forwarding* - add `TCP, Host IP 127.0.0.1, Host Port 8080, Guest Port 8080`.
3. PowerShell:
   ```powershell
   Test-NetConnection 10.0.2.15 -Port 8080    # expected in NAT mode: TcpTestSucceeded False
   Test-NetConnection 127.0.0.1 -Port 8080    # with the forward rule: True
   curl.exe -s -o NUL -w "%{http_code}`n" http://localhost:8080/
   ```
4. On Ubuntu: `sudo ufw status verbose`; if needed `sudo ufw allow 8080/tcp`.

## Lesson
Collect evidence per layer: **health -> process -> port -> bind address -> IP -> VM network mode ->
reachability -> firewall.** The first four answered it in under a minute. "Connection refused"
(immediate) and "timeout" (silent drop) point to different layers.
