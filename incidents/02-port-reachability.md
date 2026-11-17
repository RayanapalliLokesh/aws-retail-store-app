# Incident 02 - Process Running, Port Not Reachable (Catalog on the wrong port)

| | |
|---|---|
| Date | 17-Nov-2026, ~11:12:20 UTC (lab) |
| Service | Catalog |
| Trigger | Intentional: Catalog restarted with `PORT=9081` instead of `8081` (a typo-style config mistake) |

## Symptom
The Catalog process is running, but `http://localhost:8081` refuses connections, and the UI
`/catalog` page returns HTTP 500.
```
$ curl -sS -o /dev/null -w 'HTTP %{http_code}\n' http://localhost:8081/health
curl: (7) Failed to connect to localhost port 8081 after 0 ms: Could not connect to server
HTTP 000
$ curl -s -o /dev/null -w 'UI catalog page HTTP %{http_code}\n' http://localhost:8080/catalog
UI catalog page HTTP 500
```

## Investigation

1. **Is the process actually running?** Yes:
   ```
   $ pgrep -a -x catalog
   23847 /home/lokesh/aws-retail-store-app/app/bin/catalog
   ```
2. **Is it listening on the expected port?** No:
   ```
   $ ss -lntp | grep ':8081 ' || echo 'nothing listening on 8081'
   nothing listening on 8081
   ```
3. **What is the real listening port?** Search the socket table by process name instead of by port:
   ```
   $ ss -lntp | grep catalog
   LISTEN 0      4096               *:9081             *:*    users:(("catalog",pid=23847,fd=6))
   ```
4. **Why that port?** Check the environment the process was started with:
   ```
   $ tr '\0' '\n' < /proc/$(pgrep -x catalog)/environ | grep '^PORT='
   PORT=9081
   ```
5. **Which address / interface is it bound to?** `*:9081` = all addresses, IPv4 and IPv6
   (the Go server listens on `:PORT` with no address). So loopback and the VM IP both work:
   ```
   $ curl -s http://127.0.0.1:9081/health; curl -s http://10.0.2.15:9081/health
   OK
   OK
   ```
   If it had shown `127.0.0.1:9081`, only clients on this VM could reach it. That is the
   127.0.0.1 vs 0.0.0.0 difference, tested in detail in `docs/bind-address-experiment.md`.
6. **Is another process already using 8081?** No - `ss` shows nothing on 8081, so this is not a
   conflict (a conflict is incident 04).

## Root cause
Configuration error: Catalog was started with `PORT=9081`. The process was healthy, but on a port
that no client (the UI is configured with `http://localhost:8081`) was using.

## Resolution
```
$ kill $(pgrep -x catalog); sleep 1; ./scripts/run-catalog.sh 8081
catalog started, PID 23907, port 8081, log /home/lokesh/retail-logs/catalog.log
```

## Validation
```
$ ss -lntp | grep catalog
LISTEN 0      4096               *:8081             *:*    users:(("catalog",pid=23907,fd=6))
$ curl -s http://localhost:8081/health
OK
$ curl -s -o /dev/null -w 'UI catalog page HTTP %{http_code}\n' http://localhost:8080/catalog
UI catalog page HTTP 200
```

## Lesson
"The process is running" does not mean "the service is reachable". Check, in order:
process (`pgrep`) -> socket (`ss -lntp`) -> port and address in the socket line -> the config
that produced them (`/proc/<pid>/environ`, command line).
