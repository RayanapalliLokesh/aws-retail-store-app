# Linux Troubleshooting Notes (Week 1 Tasks 5, 9, 10)

## Task 5 - Which tool answers which question

| Question | Tool | Example I used |
|---|---|---|
| Is the process running? Which PID / user / how long? | `ps`, `pgrep` | `ps -o pid,ppid,user,%cpu,%mem,rss,etime,comm -p <pid>` |
| Who is using the CPU / memory right now? | `top` | `top -b -n 1 -o %CPU \| head -12` |
| How much memory is left? | `free` | `free -h` (read **available**, not free) |
| Which filesystem is full? | `df` | `df -h`, `df -i` for inodes |
| Which directory / file is big? | `du`, `find` | `du -sh dir/* \| sort -rh`, `find / -size +100M` |
| Find text in logs / config | `grep` | `grep -n ' ERROR ' ui.log` |
| Pick columns / count | `awk` | `awk '{print $1}' \| uniq -c` |
| Edit text in a stream | `sed` | `sed -n '9,12p' file` |
| Follow a log live / last lines | `tail` | `tail -f ~/retail-logs/catalog.log` |
| Read a big log page by page | `less` | `less +G ui.log`, then `?ERROR` |
| Which process listens on which port? | `ss` | `ss -lntp` |
| Does the endpoint answer, and with what? | `curl` | `curl -s -o /dev/null -w '%{http_code}'` |
| Status of a system service | `systemctl` | `systemctl is-active ufw` |
| Logs of system services | `journalctl` | `journalctl -u docker -n 3`, `journalctl --user` |
| Fix permissions / ownership | `chmod`, `chown` | `chmod +x scripts/*.sh` |

`df` vs `du`: **`df` asks the filesystem** how full it is (blocks used, including deleted-but-still-open
files). **`du` walks the directory tree** and adds up the files it can see. If `df` says full but
`du` finds much less, look for deleted files that are still open (`lsof +L1`).

---

## Task 9 - CPU / Memory investigation: "the application is slow"

Load was generated on purpose with the UI's own test endpoint
`/utility/stress/{iterations}` (Monte-Carlo Pi): 8 parallel curl loops for ~40 s.
The VM has **4 vCPUs** (`nproc`).

**Baseline**
```
$ curl -s -o /dev/null -w 'catalog page %{time_total}s\n' http://localhost:8080/catalog
catalog page 0.104792s
$ uptime
 11:13:19 up  1:46,  1 user,  load average: 1.62, 2.35, 1.86
```

**During the slowness**
```
$ uptime
 11:13:56 up  1:46,  1 user,  load average: 27.79, 8.40, 3.90
$ curl -s -o /dev/null -w 'catalog page %{time_total}s\n' http://localhost:8080/catalog
catalog page 21.812375s
```

**Which process?**
```
$ top -b -n 1 -o %CPU | head -12
top - 11:14:58 up  1:47,  1 user,  load average: 58.23, 21.44, 8.75
MiB Mem :  11520.2 total,   1233.1 free,   4044.0 used,   6693.8 buff/cache
MiB Swap:      0.0 total,      0.0 free,      0.0 used.   7476.2 avail Mem
    PID USER      PR  NI    VIRT    RES    SHR S  %CPU  %MEM     TIME+ COMMAND
  23324 lokesh    20   0 6705752 391404  25564 S 297.9   3.3   6:11.59 java
  12978 lokesh    20   0 1448.4g 464732 178308 S   0.1   3.9   0:44.79 code
```
PID 23324 is the UI (`ss -lntp` shows it on `:8080`). 298% = almost three of the four cores.

```
$ ps -eo pid,user,%cpu,%mem,rss,comm --sort=-%mem | head -4
    PID USER     %CPU %MEM   RSS COMMAND
  17659 lokesh    8.2  4.1 493176 brave
  12978 lokesh    1.0  3.9 464736 code
   8930 lokesh    5.3  3.7 447680 code

$ free -h
               total        used        free      shared  buff/cache   available
Mem:            11Gi       3.9Gi       1.2Gi       126Mi       6.5Gi       7.3Gi
Swap:             0B          0B          0B
```

**Side effect seen in the system journal** (timestamps match the load):
```
Nov 17 11:14:39 Lokesh-Ubuntu com.microsoft.VSCode.desktop[8860]: No ptyHost heartbeat after 6 seconds
Nov 17 11:14:58 Lokesh-Ubuntu com.microsoft.VSCode.desktop[8860]: No ptyHost heartbeat after 6 seconds
```

**After the load stopped**
```
$ curl -s -o /dev/null -w 'catalog page %{time_total}s\n' http://localhost:8080/catalog
catalog page 0.045625s
```

**Conclusion**
- **CPU**: saturated by the UI `java` process (~300% of 400%). The load average went to 58 on a
  4-CPU box, so many threads were waiting for CPU.
- **Memory**: not the problem. 7.3 GiB available, no swap in use, UI RSS steady at ~380 MB.
- **Is the application responsible?** Yes - the UI itself (the stress requests), not another program.
  The biggest memory users (browser, VS Code) were using little CPU.
- **Evidence**: page latency 0.10 s -> 21.8 s -> 0.05 s, load average, `top` per-process CPU,
  `free` showing plenty of available memory, journal entries at the same minute.
- Caveat I learned: a single `top -b -n 1` computes the header `%Cpu(s)` line over a very short
  interval and showed "70% idle" while the per-process line said 298%. `top -b -n 2 -d 1` (use the
  second sample) or `vmstat 1 5` gives a more reliable summary.

---

## Task 10 - Log investigation (timeline)

Logs used: `~/retail-logs/ui.log` (UI, UTC, ISO timestamps), `~/retail-logs/catalog.log`
(Catalog, UTC). The VM time zone is UTC (`timedatectl` -> `Etc/UTC`), so both logs line up.

**Find the errors and when they happened**
```
$ grep -c ' ERROR ' ~/retail-logs/ui.log
4
$ grep ' ERROR ' ~/retail-logs/ui.log | awk '{print $1}' | cut -c1-16 | uniq -c
      3 2026-11-17T11:11
      1 2026-11-17T11:12
$ grep -m1 -n -A12 ' ERROR ' ~/retail-logs/ui.log | grep -E 'ERROR|Exception|Caused by'
71:2026-11-17T11:11:56.781Z ERROR 23324 --- [or-http-epoll-2] a.w.r.e.AbstractErrorWebExceptionHandler : [2a49611e-12]  500 Server Error for HTTP GET "/"
73-java.lang.RuntimeException: java.net.ConnectException: Failed to connect to localhost/127.0.0.1:8081
```

**What happened immediately before - in the other component's log**
```
$ grep -B2 'Shutting down' ~/retail-logs/catalog.log | head -3
[GIN] 2026/11/17 - 11:11:37 | 200 |      42.241µs |  ::1 | GET "/topology"
[GIN] 2026/11/17 - 11:11:37 | 200 |     1.59267ms |  ::1 | GET "/catalog/size"
2026/11/17 11:11:54 Shutting down server...
```

**Timeline**

| Time (UTC) | Component | Event |
|---|---|---|
| 11:11:37 | Catalog | Last successful requests (200) |
| 11:11:54 | Catalog | `Shutting down server...` / `Server exiting` (received SIGTERM) |
| 11:11:56.781 | UI | `500 Server Error for HTTP GET "/"` caused by `ConnectException ... 127.0.0.1:8081` |
| 11:11:56.902 | UI | `500 Server Error for HTTP GET "/catalog"` |
| 11:12:07 | Catalog | Restarted; UI requests answered with 200 again |

Answers: **What?** Users got HTTP 500. **When?** 11:11:56 UTC. **Which component generated the
error?** The UI logged it, but the cause was Catalog. **What happened before?** Catalog shut down
2 seconds earlier.

**A warning that is *not* the problem.** On every UI start-up:
```
2026-11-17T11:09:52.890Z  WARN 23324 --- [main] o.s.a.b.c.BedrockProxyChatModel : Failed to load region from DefaultAwsRegionProviderChain, using US_EAST_1
software.amazon.awssdk.core.exception.SdkClientException: Unable to load region from any of the providers in the chain ...
```
It comes with a long stack trace, but it is a WARN from the optional Bedrock chat feature
(`retail.ui.chat.enabled: false`) not finding an AWS region on my laptop. The UI starts fine
afterwards (`Started UiApplication in 38.863 seconds`). Lesson: a stack trace in a log is not
automatically the root cause - check the level, the time, and whether it correlates with the symptom.

Other log sources checked:
```
$ docker logs catalog-db 2>&1 | grep -i warning | head -2
2026-11-17 11:09:23 0 [Warning] mariadbd: io_uring_queue_init() failed with errno 1
2026-11-17 11:09:23 0 [Warning] InnoDB: liburing disabled: falling back to innodb_use_native_aio=OFF
$ journalctl -u docker -n 3 --no-pager
```
(The MariaDB warnings are expected in a container without io_uring permission. Harmless.)
