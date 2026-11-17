# Week 1 Learning Log

## What I studied
- The five services of the AWS Retail Store sample: what each one owns, its language, port, datastore and configuration.
- Linux process, port, resource and log tools in the context of this app: `ps`, `pgrep`, `top`, `free`, `df`, `du`, `find`, `grep`, `awk`, `sed`, `tail`, `ss`, `curl`, `journalctl`, `/proc/<pid>/{cmdline,environ,fd}`.
- Writing incident reports in a fixed format: symptom -> evidence -> root cause -> fix -> validation.

## What I implemented
- Built Catalog (`go build`) and UI (`./mvnw package`) from source and ran both **directly on Ubuntu** (JDK 21 and Go installed under `~/.local/opt` because there is no sudo on this VM).
- Catalog datastore: MariaDB 10.9 container published on `127.0.0.1:3306` only.
- Start/stop scripts: `scripts/run-catalog-db.sh`, `run-catalog.sh`, `run-ui.sh`, `stop-all.sh`, `env.sh`. The DB password comes from an environment variable, never from a file.
- `scripts/health_check.py` - checks UI health, Catalog health **and** the real `/catalog` page, writes timestamped results, exit code 0/1.
- Docs: application overview, architecture V1 (+ diagram), request flows, run evidence, Linux troubleshooting; incidents 01-03; runbook `application-unavailable.md`.

## What I understood about the application
- Every service listens on 8080 inside its container; the different ports exist only in the compose port mappings.
- The UI calls the other services over HTTP using `RETAIL_UI_ENDPOINTS_*`. If an endpoint is empty it uses a built-in mock, so a missing service can be invisible.
- Orders is the only service that uses asynchronous messaging (RabbitMQ events).
- Each service has its own datastore, so one service's data model can change without breaking the others.

## Linux commands/tools I used
See `docs/linux-troubleshooting.md` (tool -> question table) and the evidence in each incident.

## What broke
| # | What I broke | How |
|---|---|---|
| 01 | Catalog process down | `kill <pid>` |
| 02 | Catalog running on the wrong port | restarted with `PORT=9081` |
| 03 | Filesystem at 96% | filled a 200 MB tmpfs in a container (VM disk is only 20% used, no sudo for a loop device) |
| CPU | UI slow | 8 parallel clients on `/utility/stress` |
| Unplanned | my own commands | `pgrep -f`/`pkill -f` matched the shell running them; one `pkill -f` killed my own shell |

## What I initially thought was wrong
- Incident 01: the UI health said `UP`, so the first idea was "the UI is fine, maybe the browser". The 500s on the pages proved otherwise.
- UI start-up log: a long `SdkClientException` stack trace looked like the cause of problems, but it is only a WARN from the disabled Bedrock chat feature.

## What evidence I collected
Command output for every step is in the incident files: `curl` status codes, `ss -lntp`, `pgrep`, `/proc/<pid>/environ`, log lines with timestamps, `df`/`du`/`find`, `top`/`free`/`uptime`.

## Actual root cause
- 01: Catalog received SIGTERM (`Shutting down server...` in its log) -> UI got connection refused -> HTTP 500.
- 02: `PORT=9081` in Catalog's environment; the UI expects 8081.
- 03: a 10 ms error-retry loop filled the current log, plus rotated logs and a heap dump never cleaned up.
- CPU: the UI process itself, ~300% CPU on 4 cores; memory was fine.

## How I fixed it
Restarted Catalog correctly (01, 02), deleted old rotated logs and the heap dump and truncated the live log (03), stopped the load (CPU). Each fix was validated with `curl` + `ss` + `health_check.py`.

## What I still do not understand
<!-- Lokesh: fill in in your own words -->

## Questions for mentor
<!-- Lokesh: fill in. Open points from this week that may be worth asking about:
     - should the UI health endpoint include its dependencies (readiness vs liveness)?
     - for the disk scenario, is a tmpfs inside a container acceptable, or should it be a real loop-mounted filesystem? -->

## Topics I need to revise
<!-- Lokesh: fill in -->
