# Distributed E-Commerce — Team Member 1

## Purpose

This folder implements the database infrastructure for the distributed e-commerce project:

- 3 database sites represented by 3 MongoDB shards
- MongoDB `mongos` query router
- 3-member Config Server Replica Set
- Schema for all required entities
- Geographic horizontal fragmentation using MongoDB Zones
- Global product fragmentation using hashed sharding
- Seed data
- Verification commands

> This setup is designed for a local university demonstration, not production. Authentication/TLS are intentionally omitted to keep the demo reproducible.

## Architecture

```text
                       Backend / mongosh
                              |
                       localhost:27017
                              |
                            mongos
                              |
                    Config Server RS (cfgRS)
                 config1 + config2 + config3
                              |
             +----------------+----------------+
             |                |                |
          rsEgypt          rsEurope           rsUSA
       "Egypt Site"      "Europe Site"      "USA Site"
             |                |                |
        EGYPT_ZONE       EUROPE_ZONE         USA_ZONE
```

Each site is a **shard**, not merely a replica-set member.

## Collections

1. `customers`
2. `products`
3. `warehouses`
4. `inventory`
5. `orders`
6. `orderItems`
7. `payments`
8. `shipments`

## Fragmentation strategy

Regional collections use compound shard keys:

```javascript
{ <regionField>: 1, <entityId>: "hashed" }
```

Examples:

```javascript
customers  -> { region: 1, customerId: "hashed" }
orders     -> { customerRegion: 1, orderId: "hashed" }
shipments  -> { warehouseRegion: 1, shipmentId: "hashed" }
```

Zones map regional ranges to physical shards:

- `EGYPT_ZONE` -> `rsEgypt`
- `EUROPE_ZONE` -> `rsEurope`
- `USA_ZONE` -> `rsUSA`

`products` is a global catalog and is sharded with:

```javascript
{ productId: "hashed" }
```

## Windows run instructions

### Requirements

Install:

- Docker Desktop
- Docker Compose v2

Make sure Docker Desktop is running.

### Start everything

Open PowerShell in this folder:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\setup.ps1
```

### Connect to MongoDB

```powershell
docker exec -it ddb-mongos mongosh --port 27017
```

Then:

```javascript
use ecommerceDB
show collections
db.customers.find()
sh.status()
```

### Check fragmentation

```javascript
use ecommerceDB
db.customers.getShardDistribution()
db.inventory.getShardDistribution()
db.orders.getShardDistribution()
```

Or run:

```powershell
docker exec ddb-mongos mongosh --port 27017 --file /scripts/07-verify-fragmentation.js
```

## Linux / macOS

```bash
chmod +x setup.sh reset.sh
./setup.sh
```

## Reset the cluster

Windows:

```powershell
.\reset.ps1
```

Linux/macOS:

```bash
./reset.sh
```

Then run setup again.

## What to show during the presentation

### 1. Three sites exist

```javascript
db.adminCommand({ listShards: 1 })
```

Expected shard names:

```text
rsEgypt
rsEurope
rsUSA
```

### 2. Zones exist

```javascript
sh.status()
```

Look for:

```text
EGYPT_ZONE
EUROPE_ZONE
USA_ZONE
```

### 3. Show regional documents

```javascript
use ecommerceDB

db.customers.find({ region: "EGYPT" })
db.customers.find({ region: "EUROPE" })
db.customers.find({ region: "USA" })
```

### 4. Show physical distribution

```javascript
db.customers.getShardDistribution()
```

### 5. Explain the shard key

Example:

```javascript
{ region: 1, customerId: "hashed" }
```

`region` keeps documents geographically local.
The hashed ID improves cardinality and avoids using only three shard-key values.

## Team integration

All backend members should connect through:

```text
mongodb://localhost:27017
```

They should **not** connect directly to `rsEgypt`, `rsEurope`, or `rsUSA`.

### Member 2

Use `inventory`.

A deliberate low-stock record exists:

```text
I-EG-001 / P001 / quantity = 2
```

This can support the concurrency-control scenario.

### Member 3

A deliberate cross-region scenario exists:

```text
European customer/order/payment
+
Egyptian warehouse/inventory/shipment
```

That allows a real multi-shard transaction demonstration.

### Member 4

Do not rely only on the baseline indexes in `05-configure-fragmentation.js`.

For the assignment, create additional query-specific indexes and record:

1. `explain("executionStats")` before
2. create index
3. `explain("executionStats")` after

### Member 5

The main project setup uses one data-bearing member per shard replica set to keep the local cluster lightweight.

For a stronger automatic-failover demonstration, Member 5 should extend one shard to 3 replica-set members before the final failure-handling demo.

## Important limitation

This project uses geographic names (Egypt, Europe, USA) to model three logical database sites on one physical laptop.

The containers simulate distributed sites. They are not actually deployed in three countries.

That distinction should be stated clearly in the report.
