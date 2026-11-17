# Request Flows

## Flow A - Browse Catalog

```
User -> UI -> Catalog Service -> Catalog Database -> Catalog Service -> UI -> User
```

What happens when I open `http://localhost:8080/catalog` (traced on my VM, 17-Nov-2026):

1. The browser sends `GET /catalog` to the **UI** (port 8080). The UI receives the request first.
2. The UI calls **Catalog** over HTTP, three calls per page. Catalog's access log shows them:
   ```
   [GIN] 2026/11/17 - 11:17:57 | 200 |  1.831805ms | 127.0.0.1 | GET "/catalog/tags"
   [GIN] 2026/11/17 - 11:17:57 | 200 |  1.541521ms | 127.0.0.1 | GET "/catalog/size?tags="
   [GIN] 2026/11/17 - 11:17:57 | 200 |   9.47882ms | 127.0.0.1 | GET "/catalog/products?order=&page=1&size=6&tags="
   ```
3. Catalog reads the products from its **MySQL/MariaDB** database `catalogdb`
   (`curl localhost:8081/topology` -> `{"databaseEndpoint":"127.0.0.1:3306","persistenceProvider":"mysql"}`).
4. Catalog returns JSON. The UI renders it into HTML and sends the page back to the user.

Answers:
- **Who receives the request first?** The UI.
- **Which service retrieves product information?** Catalog. The UI never touches the catalog database.
- **Where is it stored?** In the Catalog database (MariaDB 10.9 container on my VM, `catalogdb`, 12 products).
- **What if Catalog is unavailable?** Tested in incident 01: the UI home and `/catalog` pages return
  **HTTP 500**, while the UI's own `/actuator/health` still says `UP`. The topology page shows
  `Catalog UNHEALTHY`. If the UI has *no* catalog endpoint configured it silently uses a mock and
  the user sees products anyway (incident 06, case D).

## Flow B - Add Item to Cart

```
User -> UI -> Cart Service -> Cart Datastore -> Cart Service -> UI
```

1. User clicks "Add to cart". The browser POSTs to the UI.
2. The UI calls the **Cart** service over HTTP (`RETAIL_UI_ENDPOINTS_CARTS`), with the customer id and product id.
3. Cart writes the item to its **DynamoDB** table `Items`.
4. Cart returns the updated cart. The UI also asks Catalog for product names and prices to show the cart page.

Answers:
- **Which service owns cart data?** Cart. Only Cart reads or writes the `Items` table.
- **Why does the UI not modify the database directly?** The UI would need DB credentials and would
  have to know the table layout. Then Cart could not change its storage (in-memory -> DynamoDB)
  without also changing the UI. Going through Cart's API keeps one owner per piece of data,
  one place for validation, and one place to scale.
- **What if Cart fails while Catalog is healthy?** Browsing should keep working because it only
  needs Catalog. Cart pages and "add to cart" fail. Cart failure should **not** make Catalog
  unavailable; they are separate processes with separate data.
  *I did not run Cart on my VM (the UI used `MockCartsService`), so this answer is from reading the
  code and compose files, not from a test.*
