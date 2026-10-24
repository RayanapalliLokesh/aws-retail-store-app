#Port

grep -A2 "ports:" */docker-compose.yml

cart/docker-compose.yml:    ports:
cart/docker-compose.yml-      - "8082:8080"
cart/docker-compose.yml-    healthcheck:
--
catalog/docker-compose.yml:    ports:
catalog/docker-compose.yml-      - "8081:8080"
catalog/docker-compose.yml-    healthcheck:
--
checkout/docker-compose.yml:    ports:
checkout/docker-compose.yml-      - '8085:8080'
checkout/docker-compose.yml-    healthcheck:
--
checkout/docker-compose.yml:    ports:
checkout/docker-compose.yml-      - '6379:6379'
checkout/docker-compose.yml-    healthcheck:
--
orders/docker-compose.yml:    ports:
orders/docker-compose.yml-      - "8083:8080"
orders/docker-compose.yml-    depends_on:
--
orders/docker-compose.yml:    ports:
orders/docker-compose.yml-      - "5432:5432"
orders/docker-compose.yml-    healthcheck:
--
orders/docker-compose.yml:    ports:
orders/docker-compose.yml-      - "61616:61616"
orders/docker-compose.yml-      - "8161:8161"
--
ui/docker-compose.yml:    ports:
ui/docker-compose.yml-      - 8888:8080
ui/docker-compose.yml-    environment:


#Datastore

grep -hE "image:" */docker-compose.yml

    image: amazon/dynamodb-local:1.20.0
    image: mariadb:10.9
    image: redis:6.0-alpine
    image: postgres:16.1
    image: rabbitmq:3-management


#Upstream or Downstream

grep -n "ENDPOINTS" app/compose.override.yml

4:      - RETAIL_UI_ENDPOINTS_CATALOG=http://catalog:8080
5:      - RETAIL_UI_ENDPOINTS_CARTS=http://carts:8080
6:      - RETAIL_UI_ENDPOINTS_ORDERS=http://orders:8080
7:      - RETAIL_UI_ENDPOINTS_CHECKOUT=http://checkout:8080
33:      - RETAIL_CHECKOUT_ENDPOINTS_ORDERS=http://orders:8080


#Hidden calls

grep -rn "getProduct" ui/src/main/java | head -n 3

ui/src/main/java/com/amazon/sample/ui/services/catalog/MockCatalogService.java:146:  public Mono<ProductPage> getProducts(
ui/src/main/java/com/amazon/sample/ui/services/catalog/MockCatalogService.java:177:  public Mono<Product> getProduct(String productId) {
ui/src/main/java/com/amazon/sample/ui/services/catalog/CatalogService.java:28:  Mono<ProductPage> getProducts(String tag, String order, int page, int size);
