# Application Overview - AWS Retail Store Sample (v1.3.0)

Source: `app/src` (unmodified upstream v1.3.0). Facts below come from each service's
`docker-compose.yml`, `application.yml` / config code, and from running UI + Catalog on my VM.

The app is a small online shop: browse products, put them in a cart, check out, place an order.
It is split into five services; each one owns its own data.

## Summary table

| | UI | Catalog | Cart | Checkout | Orders |
|---|---|---|---|---|---|
| **Purpose** | Web front end. Renders pages, calls the other services | Product list, product details, tags | Shopping cart per customer | Checkout session: address, delivery, payment details | Creates and stores orders, publishes order events |
| **Language / framework** | Java 21, Spring Boot (WebFlux, Netty) | Go, Gin | Java 21, Spring Boot | Node.js, NestJS (TypeScript) | Java 21, Spring Boot |
| **Port** | 8080 (compose publishes 8888->8080) | 8080 (compose 8081->8080). **8081 on my VM** | 8080 (compose 8082) | 8080 (compose 8085) | 8080 (compose 8083) |
| **Needs to start** | Nothing. Every endpoint it does not know is replaced by a mock | With `mysql` provider: the DB (runs a migration at start-up). Default `in-memory`: nothing | With `dynamodb` provider: DynamoDB. Default `in-memory`: nothing | With `redis` provider: Redis | With `postgres`/`rabbitmq` providers: PostgreSQL + RabbitMQ |
| **Datastore** | none | MySQL / MariaDB `catalogdb` | DynamoDB table `Items` | Redis | PostgreSQL `orders` |
| **Upstream caller** | User (browser) | UI | UI | UI | Checkout (create order), UI (order pages) |
| **Downstream** | Catalog, Cart, Checkout, Orders (HTTP) | Catalog DB | DynamoDB | Redis, Orders (HTTP) | PostgreSQL, RabbitMQ |
| **Key configuration** | `RETAIL_UI_ENDPOINTS_CATALOG`, `_CARTS`, `_CHECKOUT`, `_ORDERS`, `server.port`, `server.address` | `PORT`, `RETAIL_CATALOG_PERSISTENCE_PROVIDER`, `_ENDPOINT`, `_DB_NAME`, `_USER`, `_PASSWORD` | `RETAIL_CART_PERSISTENCE_PROVIDER`, `RETAIL_CART_PERSISTENCE_DYNAMODB_ENDPOINT` | `PORT`, `RETAIL_CHECKOUT_PERSISTENCE_PROVIDER`, `_REDIS_URL`, `RETAIL_CHECKOUT_ENDPOINTS_ORDERS` | `RETAIL_ORDERS_PERSISTENCE_*`, `RETAIL_ORDERS_MESSAGING_PROVIDER`, `_RABBITMQ_ADDRESSES` |
| **Health endpoint** | `/actuator/health`, `/topology` | `/health`, `/topology` | `/actuator/health` | `/health` | `/actuator/health` |
| **Logs** | stdout (Spring Boot format, UTC). On my VM redirected to `~/retail-logs/ui.log` | stdout, one GIN access line per request. On my VM `~/retail-logs/catalog.log` | stdout | stdout | stdout |
| **If it is down** | Whole shop is down | Home and product pages return HTTP 500 (measured, see incident 01) | Cart pages fail; browsing should still work | Customers cannot check out | Checkout cannot submit orders; order history fails |

## Notes I want to remember

- **Every service listens on 8080 inside its container.** The different numbers (8081, 8082 ...)
  only exist on the host side of the docker-compose port mapping. When I run services directly on
  one machine I must give them different ports myself (`PORT=8081` for Catalog).
- **The UI hides missing services.** In `StoreServices.java` each client is created only if its
  endpoint is set (`StringUtils.hasText(...)`), otherwise a `Mock...Service` is used. The mock catalog
  even loads the same product list from a JSON file. So "the UI shows products" does not prove
  Catalog is working - check `/topology` (see incident 06).
- **`/actuator/health` of the UI only describes the UI process.** It stayed `UP` while users got
  HTTP 500 because Catalog was down (incidents 01 and 06).
- Secrets: every password is passed as an environment variable (`${DB_PASSWORD}` in compose).
  Nothing real is stored in the repository.

## What I actually ran on my VM

| Component | How | Listening | Evidence |
|---|---|---|---|
| UI | `scripts/run-ui.sh` -> `java -jar app/src/ui/target/ui-0.0.1-SNAPSHOT.jar` | `*:8080` | `docs/running-ui-and-catalog.md` |
| Catalog | `scripts/run-catalog.sh` -> `app/bin/catalog` (built with `go build`) | `*:8081` | same |
| Catalog DB | `scripts/run-catalog-db.sh` -> `mariadb:10.9` container | `127.0.0.1:3306` | same |
| Cart, Checkout, Orders | not run - UI uses its mocks (topology shows `NONE`) | - | - |
