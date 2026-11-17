# Running UI and Catalog Directly on Ubuntu (Week 1 Task 4)

Selected service for deeper investigation: **Catalog**. It has the clean path the brief suggests
(UI -> Catalog -> DB), and it is a single Go binary, so the process is easy to see.
The **UI** is also run directly on Ubuntu (Week 2 prerequisite).

## Toolchain (no sudo on this VM)

JDK 21 (Temurin) and Go 1.24.5 are unpacked under `~/.local/opt`. `scripts/env.sh` puts them on `PATH`.

```bash
cd app/src/catalog && go build -o ../../bin/catalog .        # -> app/bin/catalog (git-ignored)
cd app/src/ui && ./mvnw -DskipTests package                   # -> app/src/ui/target/ui-0.0.1-SNAPSHOT.jar
```

## Start-up

```bash
export CATALOG_DB_PASSWORD='<typed here, never saved in a file>'
./scripts/run-catalog-db.sh      # MariaDB 10.9 container, published on 127.0.0.1:3306 only
./scripts/run-catalog.sh         # Catalog on port 8081, log ~/retail-logs/catalog.log
./scripts/run-ui.sh              # UI on 0.0.0.0:8080, catalog=http://localhost:8081, log ~/retail-logs/ui.log
./scripts/stop-all.sh            # stops everything
```

## Identified facts

| | UI | Catalog |
|---|---|---|
| Startup command | `java -jar .../ui-0.0.1-SNAPSHOT.jar --server.address=0.0.0.0 --server.port=8080` | `app/bin/catalog` with env `PORT=8081` |
| Process name | `java` | `catalog` |
| Listening port | `*:8080` | `*:8081` |
| Dependencies | Catalog (via `RETAIL_UI_ENDPOINTS_CATALOG`), others mocked | MariaDB at `127.0.0.1:3306` |
| Logs | stdout -> `~/retail-logs/ui.log` | stdout -> `~/retail-logs/catalog.log` |
| Environment | `RETAIL_UI_ENDPOINTS_CATALOG=http://localhost:8081` | `PORT`, `GIN_MODE=release`, `RETAIL_CATALOG_PERSISTENCE_PROVIDER=mysql`, `..._ENDPOINT=127.0.0.1:3306`, `..._PASSWORD` |
| Health / API | `/actuator/health`, `/topology` | `/health`, `/topology`, `/catalog/products`, `/catalog/size`, `/catalog/tags` |

## Evidence (17-Nov-2026)

**Listening sockets** - I get the PID from the socket, not from `pgrep -f`, because `pgrep -f`
also matches the shell that runs it.
```
$ ss -lntp | grep -E ':(8080|8081|3306) '
LISTEN 0      4096       127.0.0.1:3306       0.0.0.0:*
LISTEN 0      4096               *:8081             *:*    users:(("catalog",pid=23309,fd=6))
LISTEN 0      4096               *:8080             *:*    users:(("java",pid=23324,fd=37))
```

**Running processes**
```
$ ps -o pid,ppid,user,%cpu,%mem,rss,etime,comm -p 23324,23309
    PID    PPID USER     %CPU %MEM   RSS     ELAPSED COMMAND
  23309    7297 lokesh    0.2  0.2 29016       01:59 catalog
  23324    7297 lokesh   56.7  3.2 378748      01:59 java

$ tr '\0' ' ' < /proc/23324/cmdline
java -jar /home/lokesh/aws-retail-store-app/app/src/ui/target/ui-0.0.1-SNAPSHOT.jar --server.address=0.0.0.0 --server.port=8080
```

**Environment the processes really got** (read from `/proc`, not from my notes)
```
$ tr '\0' '\n' < /proc/23309/environ | grep -E '^(PORT|GIN_MODE|RETAIL_CATALOG_PERSISTENCE_(PROVIDER|ENDPOINT))='
RETAIL_CATALOG_PERSISTENCE_ENDPOINT=127.0.0.1:3306
RETAIL_CATALOG_PERSISTENCE_PROVIDER=mysql
PORT=8081
GIN_MODE=release

$ tr '\0' '\n' < /proc/23324/environ | grep -E '^RETAIL_UI'
RETAIL_UI_ENDPOINTS_CATALOG=http://localhost:8081
```

**Where the logs go** - file descriptor 1 (stdout) of each process:
```
$ ls -l /proc/23309/fd/1 /proc/23324/fd/1
l-wx------ 1 lokesh lokesh 64 Nov 17 11:10 /proc/23309/fd/1 -> /home/lokesh/retail-logs/catalog.log
l-wx------ 1 lokesh lokesh 64 Nov 17 11:10 /proc/23324/fd/1 -> /home/lokesh/retail-logs/ui.log
```

**Successful API / health requests**
```
$ curl -s http://localhost:8080/actuator/health
{"status":"UP"}
$ curl -s -o /dev/null -w 'HTTP %{http_code} in %{time_total}s\n' http://localhost:8080/
HTTP 200 in 0.073050s
$ curl -s http://localhost:8081/health
OK
$ curl -s http://localhost:8081/topology
{"databaseEndpoint":"127.0.0.1:3306","persistenceProvider":"mysql"}
$ curl -s http://localhost:8081/catalog/size
{"size":12}
```

UI topology page (`/topology`, HTML converted to text):
```
Catalog | HEALTHY | Endpoint | http://localhost:8081 | Persistence Provider | mysql | Database Endpoint | 127.0.0.1:3306 | Carts | NONE | Checkout | NONE | Orders | NONE
```

**Relevant application logs**
```
$ grep -E 'Netty started|Started UiApplication' ~/retail-logs/ui.log
2026-11-17T11:10:19.004Z  INFO 23324 --- [main] o.s.b.w.e.n.NettyWebServer : Netty started on port 8080 (http)
2026-11-17T11:10:19.137Z  INFO 23324 --- [main] c.a.s.u.UiApplication      : Started UiApplication in 38.863 seconds

$ head -3 ~/retail-logs/catalog.log
Using mysql database 127.0.0.1:3306
Running database migration...
Database migration complete

$ docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Ports}}\t{{.Status}}'
NAMES        IMAGE          PORTS                      STATUS
catalog-db   mariadb:10.9   127.0.0.1:3306->3306/tcp   Up 2 minutes
```

Note: the UI needs about 40 s to start. During that time the port is not open yet, so
"connection refused" in the first seconds after a start is expected.
