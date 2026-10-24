# Application Overview

## Port

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


## Datastore

grep -hE "image:" */docker-compose.yml

    image: amazon/dynamodb-local:1.20.0
    image: mariadb:10.9
    image: redis:6.0-alpine
    image: postgres:16.1
    image: rabbitmq:3-management


## Upstream or Downstream

grep -n "ENDPOINTS" app/compose.override.yml

4:      - RETAIL_UI_ENDPOINTS_CATALOG=http://catalog:8080
5:      - RETAIL_UI_ENDPOINTS_CARTS=http://carts:8080
6:      - RETAIL_UI_ENDPOINTS_ORDERS=http://orders:8080
7:      - RETAIL_UI_ENDPOINTS_CHECKOUT=http://checkout:8080
33:      - RETAIL_CHECKOUT_ENDPOINTS_ORDERS=http://orders:8080


## Hidden calls

grep -rn "getProduct" ui/src/main/java | head -n 3

ui/src/main/java/com/amazon/sample/ui/services/catalog/MockCatalogService.java:146:  public Mono<ProductPage> getProducts(
ui/src/main/java/com/amazon/sample/ui/services/catalog/MockCatalogService.java:177:  public Mono<Product> getProduct(String productId) {
ui/src/main/java/com/amazon/sample/ui/services/catalog/CatalogService.java:28:  Mono<ProductPage> getProducts(String tag, String order, int page, int size);

## Connecting the dots between services

grep -n "ENDPOINTS" app/compose.override.yaml


4:      - RETAIL_UI_ENDPOINTS_CATALOG=http://catalog:8080
5:      - RETAIL_UI_ENDPOINTS_CARTS=http://carts:8080
6:      - RETAIL_UI_ENDPOINTS_ORDERS=http://orders:8080
7:      - RETAIL_UI_ENDPOINTS_CHECKOUT=http://checkout:8080
33:      - RETAIL_CHECKOUT_ENDPOINTS_ORDERS=http://orders:8080


grep -n "PERSISTENCE_ENDPOINT\|REDIS_URL\|DYNAMODB_ENDPOINT\|RABBITMQ_ADDRESSES" */docker-compose.yml

cart/docker-compose.yml:19:      - RETAIL_CART_PERSISTENCE_DYNAMODB_ENDPOINT=http://carts-db:8000
catalog/docker-compose.yml:20:      - RETAIL_CATALOG_PERSISTENCE_ENDPOINT=catalog-db:3306
checkout/docker-compose.yml:16:      - RETAIL_CHECKOUT_PERSISTENCE_REDIS_URL=redis://checkout-redis:6379
orders/docker-compose.yml:20:      - RETAIL_ORDERS_PERSISTENCE_ENDPOINT=orders-db:5432
orders/docker-compose.yml:25:      - RETAIL_ORDERS_MESSAGING_RABBITMQ_ADDRESSES=rabbitmq:5672


grep -rn "FanoutExchange\|TransactionalEventListener" orders/src/main/java | head

orders/src/main/java/com/amazon/sample/orders/metrics/OrdersMetrics.java:29:import org.springframework.transaction.event.TransactionalEventListener;
orders/src/main/java/com/amazon/sample/orders/metrics/OrdersMetrics.java:49:  @TransactionalEventListener
orders/src/main/java/com/amazon/sample/orders/config/messaging/RabbitMQMessagingConfig.java:26:import org.springframework.amqp.core.FanoutExchange;
orders/src/main/java/com/amazon/sample/orders/config/messaging/RabbitMQMessagingConfig.java:80:  FanoutExchange exchange() {
orders/src/main/java/com/amazon/sample/orders/config/messaging/RabbitMQMessagingConfig.java:81:    return new FanoutExchange(EXCHANGE_NAME);
orders/src/main/java/com/amazon/sample/orders/config/messaging/RabbitMQMessagingConfig.java:85:  Binding binding(Queue queue, FanoutExchange exchange) {
orders/src/main/java/com/amazon/sample/orders/messaging/OrdersEventHandler.java:27:import org.springframework.transaction.event.TransactionalEventListener;
orders/src/main/java/com/amazon/sample/orders/messaging/OrdersEventHandler.java:38:  @TransactionalEventListener



