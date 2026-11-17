# UI to Catalog Connectivity (Week 2 Task 7)

```
UI (java, *:8080)
  |  HTTP/1.1, REST + JSON, over TCP on loopback
  v
Catalog (Go, *:8081)
  |  MySQL wire protocol over TCP
  v
Catalog datastore (MariaDB 10.9, 127.0.0.1:3306 -> container 172.17.0.2:3306)
```

## Identified

| Question | Answer | Evidence |
|---|---|---|
| Catalog endpoint / hostname | `http://localhost:8081` on my VM. In docker-compose it is `http://catalog:8080` (container hostname) | `/proc/<ui-pid>/environ`, `app/src/app/compose.override.yaml` |
| Catalog port | 8081 on my VM (`PORT=8081`); 8080 inside the container image | `ss -lntp`, catalog `environ` |
| UI setting used to locate Catalog | `retail.ui.endpoints.catalog` in `application.yml`, set by env var **`RETAIL_UI_ENDPOINTS_CATALOG`** (Spring relaxed binding) | see below |
| How the UI knows where Catalog is | Only through that setting - there is no service discovery. If empty, the UI uses `MockCatalogService` | `StoreServices.java` |
| Protocol | HTTP (plain, no TLS), JSON bodies, GET requests | Catalog access log, `curl` |
| UI logs | stdout -> `~/retail-logs/ui.log` (Spring Boot format, UTC) | `/proc/<pid>/fd/1` |
| Catalog logs | stdout -> `~/retail-logs/catalog.log` (one `[GIN]` line per request) | `/proc/<pid>/fd/1` |

```
$ grep -n 'catalog' app/src/ui/src/main/resources/application.yml
17:      catalog: # http://localhost:8081

$ grep -n -A12 'public CatalogService catalogService' app/src/ui/src/main/java/com/amazon/sample/ui/config/StoreServices.java
81-    if (StringUtils.hasText(this.endpoints.getCatalog())) {
82-      return new KiotaCatalogService(
...    (otherwise) return new MockCatalogService();

$ tr '\0' '\n' < /proc/<ui-pid>/environ | grep ^RETAIL_UI
RETAIL_UI_ENDPOINTS_CATALOG=http://localhost:8081
```
The endpoint is read **once at start-up**. Changing it needs a UI restart.

## Testing Catalog directly with curl
```
$ curl -s http://localhost:8081/health
OK
$ curl -s http://localhost:8081/topology
{"databaseEndpoint":"127.0.0.1:3306","persistenceProvider":"mysql"}
$ curl -s http://localhost:8081/catalog/tags
[{"name":"accessories","displayName":"Accessories"},{"name":"clothing","displayName":"Clothing"},{"name":"food","displayName":"Food"},{"name":"vehicles","displayName":"Vehicles"}]
$ curl -s 'http://localhost:8081/catalog/products?size=1' | python3 -m json.tool | head -6
[
    {
        "id": "a1258cd2-176c-4507-ade6-746dab5ad625",
        "name": "Aqua Ace GT",
        "description": "Transform your luxury sports car into a high-speed submarine ...",
        "price": 10000,
```

## The call as Catalog sees it
One page view of `http://localhost:8080/catalog` = three HTTP calls from the UI:
```
[GIN] 2026/11/17 - 11:17:57 | 200 |    1.831805ms |       127.0.0.1 | GET      "/catalog/tags"
[GIN] 2026/11/17 - 11:17:57 | 200 |    1.541521ms |       127.0.0.1 | GET      "/catalog/size?tags="
[GIN] 2026/11/17 - 11:17:57 | 200 |     9.47882ms |       127.0.0.1 | GET      "/catalog/products?order=&page=1&size=6&tags="
```

## The TCP connections behind it
```
$ ss -tnp state established '( sport = :8081 or dport = :8081 )'
[::ffff:127.0.0.1]:8081   [::ffff:127.0.0.1]:41588  users:(("catalog",pid=23907,fd=8))
[::ffff:127.0.0.1]:41588  [::ffff:127.0.0.1]:8081   users:(("java",pid=25822,fd=40))

$ ss -tnp state established '( sport = :3306 or dport = :3306 )'
127.0.0.1:35960    127.0.0.1:3306    users:(("catalog",pid=23907,fd=3))
172.17.0.1:51354   172.17.0.2:3306                          <- docker-proxy to the container
```
The UI keeps HTTP connections open (keep-alive) and reuses them; Catalog keeps a DB connection pool.

## UI view of the dependency
```
$ curl -s http://localhost:8080/topology   (HTML -> text)
Catalog | HEALTHY | Endpoint | http://localhost:8081 | Persistence Provider | mysql | Database Endpoint | 127.0.0.1:3306 | Carts | NONE | Checkout | NONE | Orders | NONE
```
`NONE` = no endpoint configured, the UI uses its mock for that service.
