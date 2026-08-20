#!/usr/bin/env bash
set -euo pipefail

wait_mongo () {
  local container="$1"
  local port="$2"
  for _ in $(seq 1 45); do
    if docker exec "$container" mongosh --port "$port" --quiet --eval 'db.adminCommand({ping:1}).ok' >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
  done
  echo "MongoDB did not become ready in $container" >&2
  exit 1
}

echo "1/7 Starting config servers and shard servers..."
docker compose up -d config1 config2 config3 shard-egypt shard-europe shard-usa

wait_mongo ddb-config1 27019
wait_mongo ddb-shard-egypt 27018
wait_mongo ddb-shard-europe 27018
wait_mongo ddb-shard-usa 27018

echo "2/7 Initializing replica sets..."
docker exec ddb-config1 mongosh --port 27019 --quiet --eval \
'try { rs.initiate({_id:"cfgRS",configsvr:true,members:[{_id:0,host:"config1:27019"},{_id:1,host:"config2:27019"},{_id:2,host:"config3:27019"}]}) } catch(e) { print(e.message) }'

docker exec ddb-shard-egypt mongosh --port 27018 --quiet --eval \
'try { rs.initiate({_id:"rsEgypt",members:[{_id:0,host:"shard-egypt:27018"}]}) } catch(e) { print(e.message) }'
docker exec ddb-shard-europe mongosh --port 27018 --quiet --eval \
'try { rs.initiate({_id:"rsEurope",members:[{_id:0,host:"shard-europe:27018"}]}) } catch(e) { print(e.message) }'
docker exec ddb-shard-usa mongosh --port 27018 --quiet --eval \
'try { rs.initiate({_id:"rsUSA",members:[{_id:0,host:"shard-usa:27018"}]}) } catch(e) { print(e.message) }'

sleep 6

echo "3/7 Starting mongos..."
docker compose up -d mongos
wait_mongo ddb-mongos 27017

echo "4/7 Adding shards..."
docker exec ddb-mongos mongosh --port 27017 --quiet --file /scripts/03-add-shards.js

echo "5/7 Creating schema..."
docker exec ddb-mongos mongosh --port 27017 --quiet --file /scripts/04-create-schema.js

echo "6/7 Applying fragmentation and seed data..."
docker exec ddb-mongos mongosh --port 27017 --quiet --file /scripts/05-configure-fragmentation.js
docker exec ddb-mongos mongosh --port 27017 --quiet --file /scripts/06-seed-data.js

echo "7/7 Verifying..."
docker exec ddb-mongos mongosh --port 27017 --quiet --file /scripts/07-verify-fragmentation.js

echo
echo "DONE."
echo "MongoDB router: mongodb://localhost:27017"
echo "Shell: docker exec -it ddb-mongos mongosh --port 27017"
