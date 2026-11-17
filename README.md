# Retail Store DevOps - Weeks 1 and 2
Operating and troubleshooting the AWS Retail Store sample application (v1.3.0) on Linux.
Runs on an Ubuntu 26.04 VM in VirtualBox (NAT). No sudo is needed: JDK 21 and Go 1.24 are unpacked
under `~/.local/opt`; the Catalog database runs in Docker.

**Current stage:** Week 1 (Linux operations) and Week 2 (networking) are complete. UI and Catalog run
directly on Ubuntu, Catalog uses MariaDB, and six incidents are documented with evidence.
Open items that need the Windows host or sudo are listed at the end of `docs/week-02-learning-log.md`.

## Run it
```bash
cd app/src/catalog && go build -o ../../bin/catalog . && cd -     # once
cd app/src/ui && ./mvnw -DskipTests package && cd -                # once
export CATALOG_DB_PASSWORD='...'          # typed in the terminal, never stored in a file
./scripts/run-catalog-db.sh               # MariaDB on 127.0.0.1:3306
./scripts/run-catalog.sh                  # Catalog on :8081
./scripts/run-ui.sh                       # UI on 0.0.0.0:8080 -> http://localhost:8080
python3 scripts/health_check.py           # HEALTHY / UNHEALTHY with timestamps
./scripts/stop-all.sh
```

## Where things are
| Folder | Content |
|---|---|
| `docs/` | application overview, architecture, request flows, Linux and networking notes, learning logs |
| `incidents/` | 01-06: process down, port, disk, port conflict, local-works-remote-fails, UI->Catalog |
| `runbooks/` | application unavailable, application connectivity |
| `diagrams/` | application architecture V1, network architecture V1 (SVG source + PNG) |
| `scripts/` | start/stop scripts, `health_check.py`, `remote-client-test.sh`, git pre-commit hook |

## Progress
Every commit of the week adds one row (newest at the bottom).
| # | Done in | What was added |
|---|---|---|
| 1 | Lesson 0.4 | README.md, .gitignore |
| 2 | Lesson 0.5 | app/src - AWS retail store sample app v1.3.0 (unmodified) |
| 3 | W1 Task 4 | scripts/ - start/stop UI, Catalog, Catalog DB (password from env only) |
| 4 | W1 Task 1 | docs/application-overview.md |
| 5 | W1 Task 2 | docs/application-architecture-v1.md + diagram |
| 6 | W1 Task 3 | docs/request-flows.md |
| 7 | W1 Task 4 | docs/running-ui-and-catalog.md |
| 8 | W1 Task 6 | incidents/01-application-process-down.md |
| 9 | W1 Task 7 | incidents/02-port-reachability.md |
| 10 | W1 Task 8 | incidents/03-disk-utilization.md |
| 11 | W1 Tasks 5, 9, 10 | docs/linux-troubleshooting.md |
| 12 | W1 Task 11 | runbooks/application-unavailable.md |
| 13 | W1 Task 12 | scripts/health_check.py |
| 14 | W1 Task 13 | docs/week-01-learning-log.md |
| 15 | W2 Task 1 | docs/linux-network-baseline.md |
| 16 | W2 Task 2 | docs/bind-address-experiment.md, scripts/remote-client-test.sh |
| 17 | W2 Task 3 | docs/listening-sockets.md |
| 18 | W2 Incident 01 | incidents/04-port-conflict.md |
| 19 | W2 Incident 02 | incidents/05-local-works-remote-fails.md |
| 20 | W2 Task 4 | docs/vm-networking.md |
| 21 | W2 Task 5 | docs/dns-resolution.md |
| 22 | W2 Task 6 | docs/network-flow-v1.md |
| 23 | W2 Task 7 | docs/ui-catalog-connectivity.md |
| 24 | W2 Incident 03 | incidents/06-ui-catalog-connectivity.md |
| 25 | W2 Task 8 | docs/network-architecture-v1.md + diagram |
| 26 | W2 Task 9 | runbooks/application-connectivity.md |
| 27 | W2 Task 10 | docs/command-notes.md |
| 28 | W2 Task 11 | docs/week-02-learning-log.md |
| 29 | W1+W2 | README - current stage, how to run, folder map |
