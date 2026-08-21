use("ecommerceDB");

print("\n=== CUSTOMERS ===");
db.customers.getShardDistribution();

print("\n=== WAREHOUSES ===");
db.warehouses.getShardDistribution();

print("\n=== INVENTORY ===");
db.inventory.getShardDistribution();

print("\n=== ORDERS ===");
db.orders.getShardDistribution();

print("\n=== ORDER ITEMS ===");
db.orderItems.getShardDistribution();

print("\n=== PAYMENTS ===");
db.payments.getShardDistribution();

print("\n=== SHIPMENTS ===");
db.shipments.getShardDistribution();

print("\n=== FULL SHARD STATUS ===");
sh.status();
