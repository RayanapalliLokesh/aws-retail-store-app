# Application Connectivity Runbook

Use when a client "cannot reach" the Retail Store, or the UI cannot reach Catalog.
Work top to bottom and **write down the output of every step before changing anything.**
Values for this VM: UI `:8080`, Catalog `:8081`, DB `127.0.0.1:3306`, VM IP `10.0.2.15`, gateway `10.0.2.2`.

## 1. Confirm the user symptom
- Who is the client (browser on Windows? curl on the VM? the UI calling Catalog?), which URL, since when, every time or sometimes?
- Get the exact error text. A browser's "refused", "timed out" and "server error 500" point to different layers.

## 2. Test the endpoint
```bash
curl -sS -o /dev/null -w 'HTTP %{http_code} %{time_total}s ip=%{remote_ip}\n' http://<host>:<port>/<path>
```
| curl result | Layer |
|---|---|
| `(6) Could not resolve host` | DNS -> step 11 |
| `(7) ... Could not connect` / refused, instantly | nothing listening on that IP:port -> steps 3-6 |
| `(28) timed out` | packets dropped: firewall, routing, VM network mode -> steps 8-10 |
| HTTP 5xx | app reached, but failing; often a dependency -> step 12 |
| HTTP 200, slow | resources (CPU/memory) - see `application-unavailable.md` step 4 |

## 3. Check the application process
```bash
pgrep -a -x catalog ; ss -lntp | grep -E ':(8080|8081) '
```

## 4. Check the listening socket
```bash
ss -lntp "sport = :<port>"          # is anything listening? which PID?
ss -lntp | grep <process-name>      # if not on the expected port: where is it?
```
`address already in use` in a start-up log -> see who owns the port (incident 04).

## 5. Check the bind address
In the `ss` output: `127.0.0.1:<port>` / `[::ffff:127.0.0.1]:<port>` = loopback only;
`0.0.0.0:<port>` / `*:<port>` = all addresses.
```bash
tr '\0' ' ' < /proc/<PID>/cmdline      # UI: --server.address=...
```
Loopback-only while the client is on another machine -> rebind to `0.0.0.0` (incident 05).

## 6. Check local connectivity
```bash
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:<port>/
curl -s -o /dev/null -w '%{http_code}\n' http://10.0.2.15:<port>/       # through the VM's own IP
./scripts/remote-client-test.sh 172.17.0.1 <port>                      # from a separate network namespace
```
Loopback OK but VM IP fails -> bind address. All three OK -> the problem is outside the VM.

## 7. Check host IP / interface
```bash
ip -br addr ; hostname -I
```
Is the client using the right IP? Did DHCP give a new address after a reboot or a network-mode change?

## 8. Check routing
```bash
ip route
ip route get <client or destination IP>
ping -c 2 10.0.2.2
```
No default route or wrong interface -> routing. `Network is unreachable` = no route at all.

## 9. Check the VM network mode (Windows-side clients)
In NAT mode Windows cannot reach `10.0.2.15`. Check VirtualBox -> Settings -> Network: the mode,
and the port-forward rules (`Host 8080 -> Guest 8080`). Bridged / host-only: the VM has a
different IP - go back to step 7.

## 10. Check the firewall
```bash
systemctl is-active ufw
sudo ufw status verbose            # look for "deny (incoming)" and an ALLOW rule for the port
```
On Windows: the Windows Defender Firewall for the client side / port-forward.
A firewall DROP gives a **timeout**, not "refused".

## 11. Check DNS
```bash
getent hosts <name>                # what the system resolver returns (includes /etc/hosts)
dig <name> +short ; resolvectl query <name>
grep hosts /etc/nsswitch.conf      # files -> mdns (.local stops here) -> dns
```
Container names like `catalog` only resolve on the Docker network (incident 06-C).

## 12. Check the downstream dependency (UI -> Catalog -> DB)
```bash
curl -s http://localhost:8080/topology | sed 's/<[^>]*>/ /g' | tr -s ' \n' | grep -A3 -i catalog
tr '\0' '\n' < /proc/<UI PID>/environ | grep RETAIL_UI_ENDPOINTS_CATALOG
curl -s http://localhost:8081/health ; curl -s http://localhost:8081/topology
tail -5 ~/retail-logs/catalog.log          # silent log = requests are not arriving
grep -E 'Caused by' ~/retail-logs/ui.log | tail -3
docker ps --filter name=catalog-db
```
Topology `UNHEALTHY` -> Catalog unreachable (exception says why). Topology `NONE` -> no endpoint,
mock in use: the page may look fine while Catalog is not used (incident 06-D).

## 13. Validate recovery
```bash
python3 scripts/health_check.py                  # all HEALTHY, exit 0
curl -s -o /dev/null -w '%{http_code}\n' http://<client-facing URL>
```
Re-test **from the original client** (e.g. Windows), not only from the VM, then confirm with the reporter.

## 14. Escalation criteria
- The fix needs access I do not have: sudo/ufw, VirtualBox settings, Windows firewall, router, AWS.
- Root cause still unknown after steps 1-12, or the failure is intermittent and not reproducible.
- More than one service or the database shows errors at the same time (possible wider outage).
- Security impact: a service that should be loopback-only (DB) is reachable from outside, or a credential is exposed.
