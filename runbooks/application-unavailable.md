# Application Unavailable Runbook

Scope: Retail Store UI + Catalog running directly on the Ubuntu VM
(UI `:8080`, Catalog `:8081`, Catalog DB `127.0.0.1:3306`, logs in `~/retail-logs/`).

Rule: **investigate before remediating.** Do not restart anything until you have written down
what you saw - a restart destroys the evidence (process state, open sockets, last log lines).

## Symptoms
- "The site does not load", "product pages show an error", "it is very slow".

## Initial impact check
```bash
python3 scripts/health_check.py          # UI health, Catalog health, real UI page - with timestamps
```
- Everything UNHEALTHY -> UI itself is probably down.
- UI health HEALTHY but `ui-catalog-page` UNHEALTHY -> a dependency (Catalog) is the suspect.
  **The UI health endpoint stays UP even when users get 500** (incident 01).
- Write down: the time, which checks fail, and since when (ask the reporter).

## Step 1 - Verify endpoint
```bash
curl -s -o /dev/null -w 'HTTP %{http_code} in %{time_total}s\n' http://localhost:8080/catalog
curl -sS http://localhost:8081/health
```
Read the result type:
| Result | Meaning |
|---|---|
| `Could not connect` / connection refused | nothing listening on that IP:port -> Step 2/3 |
| hangs, then timeout | something drops packets, or the app is stuck -> Step 4, firewall |
| HTTP 5xx | app answers but fails - often a dependency -> Step 5/6 |
| HTTP 200 but slow | resources -> Step 4 |

## Step 2 - Check process
```bash
pgrep -a -x catalog
ss -lntp | grep -E ':(8080|8081) '       # the socket also gives the PID: users:(("java",pid=...))
ps -o pid,etime,%cpu,%mem,rss,cmd -p <PID>
```
No process -> check the log for why it ended (Step 5) **before** starting it.

## Step 3 - Check port
```bash
ss -lntp | grep <process-name>           # real port, if it is not the expected one
tr '\0' '\n' < /proc/<PID>/environ | grep -E '^PORT='
tr '\0' ' '  < /proc/<PID>/cmdline        # --server.address / --server.port for the UI
```
- Wrong port -> configuration (incident 02).
- `127.0.0.1:<port>` but clients come from another machine -> bind address (incident 05).
- "address already in use" in the log -> another process owns the port (incident 04).

## Step 4 - Check CPU / memory / disk
```bash
uptime; nproc
top -b -n 2 -d 1 -o %CPU | tail -15
free -h
df -h; df -i
```
Load average far above `nproc`, one process at hundreds of %CPU -> CPU (see `docs/linux-troubleshooting.md`).
`available` memory near zero or OOM messages (`journalctl -k | grep -i oom`) -> memory.
Filesystem at 90%+ -> incident 03 procedure.

## Step 5 - Inspect logs
```bash
tail -50 ~/retail-logs/ui.log ; tail -50 ~/retail-logs/catalog.log
grep -n ' ERROR ' ~/retail-logs/ui.log | tail
grep -nE 'Shutting down|panic|fatal' ~/retail-logs/catalog.log
docker logs --tail 50 catalog-db
```
Build a timeline across both logs (both are UTC): the first error, and what happened just before it in the other component.

## Step 6 - Check dependencies
```bash
curl -s http://localhost:8080/topology | sed 's/<[^>]*>/ /g' | tr -s ' \n' | grep -A3 -i catalog
tr '\0' '\n' < /proc/<UI PID>/environ | grep RETAIL_UI_ENDPOINTS_CATALOG
docker ps --filter name=catalog-db
curl -s http://localhost:8081/topology   # which DB Catalog uses
```
Topology `NONE` for Catalog means the UI is using the **mock** - the page may look fine while
Catalog is not used at all (incident 06).

## Step 7 - Remediation
Fix the cause you found, the smallest change first:
| Cause | Action |
|---|---|
| Process stopped / crashed | `./scripts/run-catalog.sh` or `./scripts/run-ui.sh` (after reading the log) |
| Wrong port / endpoint / bind | restart with the correct value |
| DB container down | `export CATALOG_DB_PASSWORD=...; ./scripts/run-catalog-db.sh`, then Catalog |
| Disk full | clean safely (incident 03) |
| CPU saturated by one client | find and stop the source of load |

## Step 8 - Validation
```bash
python3 scripts/health_check.py          # all HEALTHY, exit code 0
ss -lntp | grep -E ':(8080|8081) '
tail -3 ~/retail-logs/catalog.log        # fresh 200 lines from the UI
```
Then confirm with the person who reported it.

## Escalation criteria
Escalate (mentor / service owner) when:
- the same failure comes back after the fix, or the cause is still unknown after Steps 1-6 (~30 min);
- data loss or corruption is suspected (DB errors, migration failures);
- the fix needs access I do not have (sudo, firewall, VirtualBox/host settings, AWS);
- a credential may have been exposed - rotate it first, then escalate.
