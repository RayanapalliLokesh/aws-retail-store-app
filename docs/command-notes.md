# Command Notes

Only commands I actually used in this project, with the flags I needed.

## curl
```bash
curl -s -o /dev/null -w "%{http_code}" http://localhost:8080
```
Purpose: check an endpoint and print only the HTTP status code.
- `-s` silent (no progress bar)
- `-o /dev/null` throw the response body away
- `-w` print selected response metadata: `%{http_code}`, `%{time_total}`, `%{remote_ip}`, `%{remote_port}`
- `-S` (with `-s`) still show errors - `curl: (6)` DNS, `(7)` connect refused, `(28)` timeout

Use case: health checks, measuring latency (0.10 s -> 21.8 s under load), telling DNS / refused / HTTP errors apart.

```bash
curl --resolve retail.local:8080:10.0.2.15 http://retail.local:8080/
```
Purpose: connect to a name without DNS or `/etc/hosts` - test a name -> IP mapping without root.

## ss
```bash
ss -lntp                       # listening TCP sockets, numeric, with process
ss -lntp 'sport = :8081'       # only port 8081
ss -lntpH 'sport = :8080' | grep -oP 'pid=\K[0-9]+'    # PID that owns a port
ss -tnp state established '( sport = :8081 or dport = :8081 )'
```
- `-l` listening, `-n` numeric, `-t` TCP / `-u` UDP, `-p` process, `-H` no header
Use case: who listens where; bind address (`127.0.0.1:` vs `*:`); live connections UI -> Catalog -> DB.
Why I get the PID from `ss` and not `pgrep -f`: `pgrep -f`/`pkill -f` also match the shell running
the command - one `pkill -f` killed my own shell.

## lsof
```bash
lsof -nP -iTCP:8081 -sTCP:LISTEN
```
- `-n` no DNS, `-P` no port names, `-iTCP:8081` that port, `-sTCP:LISTEN` listening only
Use case: same answer as `ss`, from the process side (incident 04). `lsof +L1` finds deleted-but-open files (disk full but `du` finds nothing).

## /proc
```bash
tr '\0' ' '  < /proc/<PID>/cmdline        # exact command line
tr '\0' '\n' < /proc/<PID>/environ        # environment the process really got (PORT, RETAIL_*)
ls -l /proc/<PID>/fd/1                    # where stdout (the log) goes
```
Use case: proving the config a running process uses (`PORT=9081` in incident 02).

## ps / pgrep
```bash
ps -o pid,ppid,user,%cpu,%mem,rss,etime,comm -p <PID>
ps -eo pid,user,%cpu,%mem,rss,comm --sort=-%cpu | head
pgrep -a -x catalog                       # -x exact process name, -a show command line
```

## top / free / uptime / vmstat
```bash
top -b -n 2 -d 1 -o %CPU | tail -15       # batch mode, 2 samples (the first sample's summary is unreliable)
free -h                                   # read the "available" column
uptime                                    # load average 1/5/15 min - compare with nproc
vmstat 1 3
```

## df / du / find
```bash
df -h ; df -i                             # space and inodes per filesystem
du -sh /srv/app/* | sort -rh              # biggest directories
find /srv/app -type f -size +10M -printf "%s\t%TY-%Tm-%Td %TH:%TM\t%p\n" | sort -rn | numfmt --to=iec --field=1
find /srv/app/logs -name "catalog.log.*" -mtime +7 -print -delete
: > logfile                               # truncate a log that a process still has open
```

## grep / awk / tail
```bash
grep -n ' ERROR ' ~/retail-logs/ui.log
grep -m1 -A12 ' ERROR ' ui.log | grep -E 'ERROR|Caused by'
grep -B2 'Shutting down' catalog.log      # what happened just before
grep ' ERROR ' ui.log | awk '{print $1}' | cut -c1-16 | uniq -c     # errors per minute
tail -f ~/retail-logs/catalog.log
```

## ip
```bash
ip -br addr                  # brief: interface, state, addresses
ip route                     # main route table
ip route get <ip>            # which route/interface/source the kernel will really use
ip route show table local    # the machine's own addresses
ip neigh show dev enp0s3     # ARP cache (gateway MAC)
```

## DNS
```bash
getent hosts <name>          # what applications get (files + mdns + dns, per nsswitch.conf)
nslookup github.com
dig github.com +noall +answer +stats
dig @49.45.0.3 github.com +short     # ask a specific server
resolvectl dns ; resolvectl query github.com
```

## Other
```bash
tracepath -n -m 6 1.1.1.1    # path / hops (behind VirtualBox NAT: everything "ends" at 10.0.2.2)
systemd-detect-virt          # oracle = VirtualBox
timedatectl                  # time zone - needed to line up log timestamps
journalctl --user -n 20 ; journalctl -u docker -n 20
docker logs --tail 50 catalog-db
python3 -m http.server 9090 --bind 127.0.0.1    # quick test listener
```
