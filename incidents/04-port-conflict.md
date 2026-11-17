# Incident 04 - Port Conflict

| | |
|---|---|
| Date | 17-Nov-2026, 11:17:02 UTC (lab) |
| Service | Catalog (second instance) |
| Trigger | Intentional: started a second Catalog with `PORT=8081` while the first one was running |

## Symptom
The new process starts, runs its DB migration, then exits with code 1:
```
$ PORT=8081 RETAIL_CATALOG_PERSISTENCE_PROVIDER=mysql ... ./app/bin/catalog; echo "exit code $?"
Using mysql database 127.0.0.1:3306
Running database migration...
Database migration complete
[GIN-debug] [WARNING] Running in "debug" mode. Switch to "release" mode in production.
...
2026/11/17 11:17:03 listen: listen tcp :8081: bind: address already in use
exit code 1
```
Same thing with another program on the UI port:
```
$ python3 -m http.server 8080
OSError: [Errno 98] Address already in use
```
Note: the failing Catalog had already connected to the DB and run a migration before it tried
to open the port. A port conflict is only detected at `bind()`, which can be late in start-up.

## Evidence
```
$ ss -lntp 'sport = :8081'
State  Recv-Q Send-Q Local Address:Port Peer Address:PortProcess
LISTEN 0      4096               *:8081            *:*    users:(("catalog",pid=23907,fd=6))
```

## Investigation
1. The error text `bind: address already in use` / `Errno 98` (`EADDRINUSE`) means the kernel
   refused to create a listening socket for that IP+port because another socket already has it.
2. Who owns the port? `ss` filter on the source port gives the PID: **23907**.
3. What is PID 23907, and since when?
   ```
   $ ps -o pid,ppid,user,lstart,cmd -p 23907
       PID    PPID USER                      STARTED CMD
     23907    7297 lokesh   Tue Nov 17 11:12:21 2026 /home/lokesh/aws-retail-store-app/app/bin/catalog
   $ lsof -nP -iTCP:8081 -sTCP:LISTEN
   COMMAND   PID   USER FD   TYPE DEVICE SIZE/OFF NODE NAME
   catalog 23907 lokesh 6u  IPv6 100002      0t0  TCP *:8081 (LISTEN)
   ```
   It is the existing, healthy Catalog started at 11:12:21 - not a stale or unknown process.
4. The existing socket is bound to `*` (all addresses), so no other IP on this machine can use 8081 either.

## Root cause
Two processes were configured with the same port. The first one (PID 23907) owned `*:8081`, so
the second one's `bind()` failed with `EADDRINUSE` and it exited.

## Resolution
Decide which process should own the port. Here the running Catalog is the correct one, so the
second instance gets a free port. (If the owner had been a forgotten old process, stopping it
would be the fix.)
```
$ ss -lnt | grep -c ':8091 ' || echo '8091 is free'
0
8091 is free
$ PORT=8091 ... nohup ./app/bin/catalog > /tmp/catalog-8091.out 2>&1 &
$ ss -lntp | grep -E ':(8081|8091) '
LISTEN 0      4096               *:8081             *:*    users:(("catalog",pid=23907,fd=6))
LISTEN 0      4096               *:8091             *:*    users:(("catalog",pid=26058,fd=6))
```

## Validation
```
$ curl -s localhost:8081/health; curl -s localhost:8091/health
OK
OK
```
The second instance was then stopped again (`8091 released`).

## Prevention
- Keep a port plan for the VM (UI 8080, Catalog 8081, DB 3306 ...) in `docs/listening-sockets.md`.
- Check before starting: `ss -lnt "sport = :<port>"` must be empty.
- Run each service under one supervisor so it cannot be started twice by hand.
