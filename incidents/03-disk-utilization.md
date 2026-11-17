# Incident 03 - Disk Utilization Above 90%

| | |
|---|---|
| Date | 17-Nov-2026, ~11:13 UTC (lab) |
| Scenario | Application server filesystem crossed 90% |

## How the scenario was built (honest note)
My VM disk is only ~20% used (`/dev/sda2 171G 32G 130G 20% /`) and I have no sudo to create and
mount a loop-device filesystem. So I reproduced the problem on a **200 MB tmpfs mounted at
`/srv/app` inside a throw-away container** (`disk-lab`, hostname `app-server`). It contains an
app-server-like layout: binary, data, a fast-growing current log, six rotated logs from early
November, and a forgotten heap dump. `df`, `du` and `find` behave exactly as on a real filesystem.

```bash
docker run -d --name disk-lab --hostname app-server --tmpfs /srv/app:size=200m,mode=1777 mariadb:10.9 sleep infinity
# then filled /srv/app/{bin,data,logs,tmp} - see "Evidence" for the result
```

## Symptom
```
$ df -h /srv/app
Filesystem      Size  Used Avail Use% Mounted on
tmpfs           200M  191M   10M  96% /srv/app
```

## Investigation

**1. Which filesystem is affected?** Only `/srv/app`; the root disk is fine.
```
$ df -h -x overlay
Filesystem      Size  Used Avail Use% Mounted on
tmpfs            64M     0   64M   0% /dev
/dev/sda2       171G   32G  130G  20% /etc/hosts
tmpfs           200M  191M   10M  96% /srv/app
```

**2. Space or inodes?** Space. Inodes are at 1%, so this is not "too many small files".
```
$ df -i /srv/app
Filesystem      Inodes IUsed   IFree IUse% Mounted on
tmpfs          1474591    15 1474576    1% /srv/app
```

**3. Largest directories**
```
$ du -sh /srv/app/* | sort -rh
157M	/srv/app/logs
25M	/srv/app/tmp
5.0M	/srv/app/bin
4.0M	/srv/app/data
```

**4. Largest files (with modification time)**
```
$ find /srv/app -type f -size +10M -printf "%s\t%TY-%Tm-%Td %TH:%TM\t%p\n" | sort -rn | numfmt --to=iec --field=1
85M 2026-11-17 11:13 /srv/app/logs/catalog.log
25M 2026-11-10 14:02 /srv/app/tmp/heapdump-20261110.hprof
12M 2026-11-06 23:59 /srv/app/logs/catalog.log.2026-11-06
12M 2026-11-05 23:59 /srv/app/logs/catalog.log.2026-11-05
12M 2026-11-04 23:59 /srv/app/logs/catalog.log.2026-11-04
12M 2026-11-03 23:59 /srv/app/logs/catalog.log.2026-11-03
12M 2026-11-02 23:59 /srv/app/logs/catalog.log.2026-11-02
12M 2026-11-01 23:59 /srv/app/logs/catalog.log.2026-11-01
```

**5. Are application logs contributing?** Yes - logs are 157 MB of 191 MB (82%). The current log
is 85 MB and is the same error repeated over a million times (a retry loop):
```
$ tail -1 /srv/app/logs/catalog.log; grep -c ERROR /srv/app/logs/catalog.log
2026-11-17 11:20:01 ERROR [catalog] db connection lost, retrying in 10ms
1206581
```

**6. What can be cleaned safely?**

| Item | Size | Safe? | Why |
|---|---|---|---|
| `catalog.log.2026-11-0[1-6]` | 72 MB | Yes | Rotated, older than 7 days, not open by any process |
| `heapdump-20261110.hprof` | 25 MB | Yes (after checking nobody needs it) | One-off debug artefact from a week ago |
| `catalog.log` (current) | 85 MB | **Truncate, do not delete** | A running process keeps writing to the open file. `rm` frees nothing until the process restarts (the deleted file stays open - visible with `lsof +L1`). `: > file` empties it in place |
| `bin/`, `data/` | 9 MB | No | The application itself and its data |

```
$ find /srv/app/logs -name "catalog.log.*" -mtime +7 | sort
/srv/app/logs/catalog.log.2026-11-01  ... (all six)
```

## Root cause
1. An error retry loop (`db connection lost, retrying in 10ms`) wrote ~1.2 million lines into
   the current log, and
2. rotated logs and an old heap dump were never removed (no retention policy).

## Resolution
```
$ find /srv/app/logs -name "catalog.log.*" -mtime +7 -print -delete
/srv/app/logs/catalog.log.2026-11-06 ... /srv/app/logs/catalog.log.2026-11-01
$ rm -v /srv/app/tmp/heapdump-20261110.hprof
removed '/srv/app/tmp/heapdump-20261110.hprof'
$ : > /srv/app/logs/catalog.log
```

## Validation
```
$ df -h /srv/app
Filesystem      Size  Used Avail Use% Mounted on
tmpfs           200M  9.0M  191M   5% /srv/app
$ curl -s http://localhost:8081/health; curl -s localhost:8080/actuator/health
OK
{"status":"UP"}
```
Test container removed afterwards (`docker rm -f disk-lab`).

## Prevention / next action
- Log retention with `logrotate` (`daily`, `rotate 7`, `compress`, `copytruncate` for apps that
  cannot reopen their log file).
- Fix the cause of the noise: a 10 ms retry loop should use back-off and log once per interval.
- Alert at 80% disk, before it becomes 90%+.
- Keep heap dumps and other debug files in a separate directory with its own cleanup.
