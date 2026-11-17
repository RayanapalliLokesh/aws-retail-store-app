# Incident 01 - Application Process Down (Catalog)

| | |
|---|---|
| Date | 17-Nov-2026, 11:11:54 - 11:12:07 UTC (13 s, lab) |
| Service | Catalog (Go binary, port 8081) |
| Severity (lab) | High: product pages down for all users |
| Trigger | Intentional: `kill <catalog PID>` (SIGTERM) |

## Incident summary
The Catalog process was stopped. The UI kept running and reported itself healthy, but every page
that shows products returned HTTP 500.

## Impact
- Home page `/` and `/catalog` returned **HTTP 500** to users.
- The UI health endpoint still answered `{"status":"UP"}` (HTTP 200), so a check on UI health
  alone would **not** have noticed the outage.

## Observed symptom
```
$ curl -s -o /dev/null -w 'UI home     HTTP %{http_code}\n' http://localhost:8080/
UI home     HTTP 500
$ curl -s -o /dev/null -w 'UI catalog  HTTP %{http_code}\n' http://localhost:8080/catalog
UI catalog  HTTP 500
$ curl -s -o /dev/null -w 'UI health   HTTP %{http_code}\n' http://localhost:8080/actuator/health
UI health   HTTP 200
```

## Investigation (in order, without restarting first)

1. **Confirm the symptom** - done above: pages 500, UI process alive.
2. **Is the dependency reachable?**
   ```
   $ curl -sS http://localhost:8081/health
   curl: (7) Failed to connect to localhost port 8081 after 0 ms: Could not connect to server
   ```
   "Could not connect" (connection refused) = nothing accepts connections on that port.
   That is different from a timeout (would point at network/firewall) or an HTTP error (app up but failing).
3. **Does the process exist?**
   ```
   $ pgrep -a -x catalog || echo 'no catalog process'
   no catalog process
   ```
4. **Is the port listening?**
   ```
   $ ss -lntp | grep ':8081 ' || echo 'nothing listening on 8081'
   nothing listening on 8081
   ```
5. **Service status** - Catalog is started by my script, not by systemd, so there is no
   `systemctl status` for it. The process table and the socket table are the status.
6. **Logs - Catalog** (last lines before it died):
   ```
   $ tail -4 ~/retail-logs/catalog.log
   [GIN] 2026/11/17 - 11:11:37 | 200 |      42.241µs |  ::1 | GET "/topology"
   [GIN] 2026/11/17 - 11:11:37 | 200 |     1.59267ms |  ::1 | GET "/catalog/size"
   2026/11/17 11:11:54 Shutting down server...
   2026/11/17 11:11:54 Server exiting
   ```
   `Shutting down server...` is Catalog's own graceful-shutdown message. It runs when the process
   receives SIGTERM/SIGINT, so this was a **stop**, not a crash (a crash would show a panic /
   stack trace, or nothing at all for `kill -9` or the OOM killer).
7. **Logs - UI** (two seconds later):
   ```
   2026-11-17T11:11:56.781Z ERROR 23324 --- [or-http-epoll-2] a.w.r.e.AbstractErrorWebExceptionHandler : [2a49611e-12]  500 Server Error for HTTP GET "/"
   java.lang.RuntimeException: java.net.ConnectException: Failed to connect to localhost/127.0.0.1:8081
   ```
8. **UI topology page** confirms it from the UI's point of view:
   ```
   Catalog | UNHEALTHY | Endpoint | http://localhost:8081
   ```

## Commands used
`curl`, `curl -w '%{http_code}'`, `pgrep -a -x`, `ss -lntp`, `tail`, `grep`.

## Root cause
The Catalog process was terminated by a signal at 11:11:54 (graceful shutdown in its log).
With no process listening on 8081, every UI call to Catalog got "connection refused" and the UI
turned that into HTTP 500 for the user.

## Resolution
```
$ ./scripts/run-catalog.sh
catalog started, PID 23780, port 8081, log /home/lokesh/retail-logs/catalog.log
```

## Validation
```
$ ss -lntp | grep ':8081 '
LISTEN 0      4096               *:8081             *:*    users:(("catalog",pid=23780,fd=6))
$ curl -s http://localhost:8081/health
OK
$ curl -s -o /dev/null -w 'UI home     HTTP %{http_code}\n' http://localhost:8080/
UI home     HTTP 200
$ curl -s -o /dev/null -w 'UI catalog  HTTP %{http_code}\n' http://localhost:8080/catalog
UI catalog  HTTP 200
Catalog | HEALTHY | Endpoint | http://localhost:8081       (UI /topology)
```
Catalog log shows the UI's requests arriving again at 11:12:07.

## Prevention / next action
- Run Catalog under a supervisor (systemd unit with `Restart=on-failure`, or a container with a
  restart policy). Note: `Restart=on-failure` would *not* restart after a clean SIGTERM - that is correct for a deliberate stop.
- Monitor what users see, not only `/actuator/health`: `scripts/health_check.py` now checks
  Catalog `/health` and the UI `/catalog` page as well.
- Lesson: **the UI health endpoint is not an end-to-end check.**
