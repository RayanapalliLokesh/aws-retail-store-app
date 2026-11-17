# Incident 06 - Breaking UI -> Catalog Connectivity

Date: 17-Nov-2026, 11:18 - 11:19 UTC (lab). Four failures, introduced **one at a time**, each
restored before the next. Observation set for every case: UI health, UI topology, UI `/catalog`
page (status + does the product "Aqua Ace GT" appear), UI log, Catalog log.

## Results at a glance

| Case | What I broke | UI health | Topology: Catalog | User: `/catalog` | Products shown | UI log clue |
|---|---|---|---|---|---|---|
| A | Stopped Catalog | UP (200) | UNHEALTHY | **500** | no | `ConnectException: Connection refused` |
| B | UI endpoint -> wrong port `http://localhost:9999` | UP (200) | UNHEALTHY | **500** | no | `Failed to connect to localhost/127.0.0.1:9999` |
| C | UI endpoint -> wrong hostname `http://catalog:8081` | UP (200) | UNHEALTHY | **500** | no | `UnknownHostException: catalog: Temporary failure in name resolution` |
| D | UI endpoint **empty** + Catalog stopped | UP (200) | **NONE** | **200** | **yes** | nothing - no error at all |

## Case A - Catalog stopped
```
$ kill $(ss -lntpH 'sport = :8081' | grep -oP 'pid=\K[0-9]+'); ss -lnt | grep ':8081 ' || echo 'nothing on 8081'
nothing on 8081
11:18:18  {"status":"UP"} <- UI health HTTP 200
Catalog | UNHEALTHY | Endpoint | http://localhost:8081
UI /catalog HTTP 500 in 0.046708s          products found: 0
UI log:      Caused by: java.net.ConnectException: Connection refused (connect failed)
Catalog log: 2026/11/17 11:18:17 Server exiting
```
- Is UI down? **No.** Is Catalog down? **Yes** - no process, no socket.
- Connectivity broken? Only because the far end is gone. Application degraded? Yes - every product page fails.
- Fix: `./scripts/run-catalog.sh 8081` -> `recovered: UI /catalog HTTP 200`.

## Case B - wrong Catalog port in UI configuration
```
$ ./scripts/run-ui.sh 0.0.0.0 8080 "http://localhost:9999"
11:18:32  {"status":"UP"} <- UI health HTTP 200
Catalog | UNHEALTHY | Endpoint | http://localhost:9999
UI /catalog HTTP 500 in 0.110259s          products found: 0
UI log:      Caused by: java.net.ConnectException: Failed to connect to localhost/127.0.0.1:9999
Catalog log: (last line still 11:18:21 - no new requests arrive)
$ curl -sS http://localhost:9999/health
curl: (7) Failed to connect to localhost port 9999 after 0 ms: Could not connect to server
```
- UI down? No. Catalog down? **No** - healthy on 8081, but **its log is silent**, the requests never reach it.
- Connectivity broken? **Yes** - configuration points to a port where nothing listens. Degraded? Yes.
- Key clue: the port number in the UI's own error message and in `/topology` does not match `ss -lntp`.

## Case C - wrong Catalog hostname
The compose files use the hostname `catalog`, which only exists on the Docker network. Copying it
to a VM where services run as plain processes is an easy mistake.
```
$ ./scripts/run-ui.sh 0.0.0.0 8080 "http://catalog:8081"
11:18:44  {"status":"UP"} <- UI health HTTP 200
Catalog | UNHEALTHY | Endpoint | http://catalog:8081
UI /catalog HTTP 500 in 0.106144s          products found: 0
UI log:      Caused by: java.net.UnknownHostException: catalog: Temporary failure in name resolution
$ getent hosts catalog || echo 'catalog: name does not resolve'
catalog: name does not resolve
```
- UI down? No. Catalog down? No. Connectivity broken? **Yes - at the DNS step**, before any TCP
  connection. This is a DNS / configuration failure, not a network-path failure.

## Case D - endpoint empty: the fallback hides the failure
Catalog was **stopped** and the UI started with `RETAIL_UI_ENDPOINTS_CATALOG=` (empty).
```
$ tr '\0' '\n' < /proc/<ui-pid>/environ | grep ^RETAIL_UI_ENDPOINTS_CATALOG
RETAIL_UI_ENDPOINTS_CATALOG=
11:19:13  {"status":"UP"} <- UI health HTTP 200
Catalog | NONE | Carts | NONE
UI /catalog HTTP 200 in 0.082763s          products found: 1   ("Aqua Ace GT" is on the page)
UI log:      no new ERROR
Catalog log: 2026/11/17 11:19:00 Server exiting       (Catalog is down the whole time)
```
- Is fallback/standalone behaviour hiding the dependency failure? **Yes, completely.** With an
  empty endpoint the UI uses `MockCatalogService`, which loads the same product list from a JSON
  file inside the UI jar. The user sees a normal shop, health is green, and there are no errors.
  The only signals: topology shows **`NONE`** instead of `HEALTHY`, and Catalog's access log gets
  no requests.
- In a real shop this is dangerous: prices and stock would be fixed demo data, and changes in the
  Catalog DB would never show up.

## Restore and validation
```
$ ./scripts/run-catalog.sh 8081 ; ./scripts/run-ui.sh 0.0.0.0 8080 "http://localhost:8081"
11:19:25  {"status":"UP"} <- UI health HTTP 200
Catalog | HEALTHY | Endpoint | http://localhost:8081
UI /catalog HTTP 200 in 0.218151s          products found: 1
Catalog log: [GIN] 2026/11/17 - 11:19:26 | 200 | 9.331121ms | 127.0.0.1 | GET "/catalog/products?..."
```

## Classifying the failures

| Case | Application failure | Network failure | Dependency failure | DNS | Config |
|---|---|---|---|---|---|
| A | | | **yes** (Catalog process down) | | |
| B | | connection refused (symptom) | | | **yes** (wrong port) |
| C | | | | **yes** (name does not resolve) | **yes** (wrong hostname) |
| D | | | **yes, hidden** | | **yes** (endpoint missing) |

## Lessons
1. **UI `/actuator/health` was UP in all four cases.** It answers "is the UI process alive", not
   "can users shop". Use `/topology`, a real page check (`scripts/health_check.py`) or the Catalog
   log for the dependency.
2. Read the exact exception: `Connection refused` (nothing on that port), `UnknownHostException`
   (DNS), `timeout` (path / firewall / overloaded). Each one points to a different layer.
3. When the provider's access log is **silent**, the requests are not arriving - look at the caller's config.
4. A mock fallback is useful for demos but should be visible. For production it should be off, or
   the readiness check should fail when a configured dependency is missing.
