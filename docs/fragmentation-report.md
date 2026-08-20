# Fragmentation Report — Distributed E-Commerce and Order Management System

## 1. Objective

The database is distributed across three logical database sites using MongoDB sharding.

The three logical sites are:

| Site | MongoDB shard | Zone |
|---|---|---|
| Egypt | `rsEgypt` | `EGYPT_ZONE` |
| Europe | `rsEurope` | `EUROPE_ZONE` |
| USA | `rsUSA` | `USA_ZONE` |

## 2. What Was Fragmented?

The following collections are horizontally fragmented according to geographical region:

- Customers
- Warehouses
- Inventory
- Orders
- Order Items
- Payments
- Shipments

The Products collection is treated as a global catalog and is fragmented using hashed sharding on `productId`.

## 3. How Was the Data Fragmented?

### Geographic horizontal fragmentation

The regional collections use a compound shard key whose first field identifies the region and whose second field is the hashed entity identifier.

| Collection | Shard key |
|---|---|
| Customers | `{ region: 1, customerId: "hashed" }` |
| Warehouses | `{ region: 1, warehouseId: "hashed" }` |
| Inventory | `{ region: 1, inventoryId: "hashed" }` |
| Orders | `{ customerRegion: 1, orderId: "hashed" }` |
| Order Items | `{ orderRegion: 1, orderItemId: "hashed" }` |
| Payments | `{ region: 1, paymentId: "hashed" }` |
| Shipments | `{ warehouseRegion: 1, shipmentId: "hashed" }` |

The regional field is the shard-key prefix and is used by MongoDB Zones to keep regional data on the selected site.

The hashed entity identifier provides higher cardinality than a region-only shard key.

### Product fragmentation

Products use:

```javascript
{ productId: "hashed" }
```

The product catalog is global rather than owned by one region, so hash-based fragmentation distributes product data without assigning a product to a geographical zone.

## 4. Where Is Each Fragment Stored?

| Data | Site |
|---|---|
| `EGYPT` regional documents | Egypt site / `rsEgypt` |
| `EUROPE` regional documents | Europe site / `rsEurope` |
| `USA` regional documents | USA site / `rsUSA` |
| Product documents | Hashed across available shards |

MongoDB Zone Sharding enforces the geographic placement.

## 5. Why Was This Approach Chosen?

### Data locality

Customers, orders, inventory, warehouses, payments, and shipments naturally contain geographical information. Keeping related data in its region reduces unnecessary access to unrelated sites.

### Targeted routing

Queries containing the shard-key prefix can be routed by `mongos` to the relevant regional shard instead of broadcasting every operation to all sites.

### Scalability

The database workload is divided across multiple shards instead of being handled by a single database server.

### Distributed-transaction support

The design intentionally permits cross-region business operations. For example, a European customer can order a product stocked in Egypt. The order/payment can therefore affect the Europe shard while inventory/shipment data affects the Egypt shard.

### Better shard-key cardinality

Using only `region` would provide only three distinct shard-key values. A hashed entity ID is included as the second component to provide better cardinality while retaining the geographical prefix.

## 6. MongoDB Components

The local demonstration contains:

- 1 `mongos` query router
- 1 three-member Config Server Replica Set (`cfgRS`)
- 3 shard replica sets:
  - `rsEgypt`
  - `rsEurope`
  - `rsUSA`

The application connects only to `mongos`.

## 7. Verification

The implementation can be verified using:

```javascript
db.adminCommand({ listShards: 1 })
sh.status()
sh.getShardedDataDistribution()

use ecommerceDB
db.customers.getShardDistribution()
db.inventory.getShardDistribution()
db.orders.getShardDistribution()
```

Targeted query routing can also be inspected with:

```javascript
db.customers.find({
  region: "EGYPT",
  customerId: "C-EG-001"
}).explain("executionStats")
```

## 8. Demonstration Limitation

The three sites are simulated as independent Docker containers on one physical computer.

Therefore, this is a logical distributed-database demonstration rather than a real geographically distributed deployment.

## 9. Conclusion

The proposed design satisfies the fragmentation objective by creating three database sites, dividing regional data using horizontal fragmentation, controlling fragment placement with MongoDB Zones, and retaining a separate hashed-fragmentation strategy for the global Product catalog.
