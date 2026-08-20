$ErrorActionPreference = "Stop"

function Wait-ContainerMongo {
    param(
        [string]$Container,
        [int]$Port,
        [int]$Attempts = 45
    )

    for ($i = 1; $i -le $Attempts; $i++) {
        docker exec $Container mongosh --port $Port --quiet --eval "db.adminCommand({ ping: 1 }).ok" *> $null
        if ($LASTEXITCODE -eq 0) {
            return
        }
        Start-Sleep -Seconds 2
    }

    throw "MongoDB did not become ready in container $Container."
}

Write-Host "1/7 Starting config servers and shard servers..."
docker compose up -d config1 config2 config3 shard-egypt shard-europe shard-usa

Wait-ContainerMongo "ddb-config1" 27019
Wait-ContainerMongo "ddb-shard-egypt" 27018
Wait-ContainerMongo "ddb-shard-europe" 27018
Wait-ContainerMongo "ddb-shard-usa" 27018

Write-Host "2/7 Initializing replica sets..."
docker exec ddb-config1 mongosh --port 27019 --quiet --file /scripts/01-init-config.js 2>$null
if ($LASTEXITCODE -ne 0) { Write-Host "Config replica set may already be initialized; continuing." }

docker exec ddb-shard-egypt mongosh --port 27018 --quiet --eval 'rs.initiate({_id:"rsEgypt",members:[{_id:0,host:"shard-egypt:27018"}]})' 2>$null
if ($LASTEXITCODE -ne 0) { Write-Host "Egypt replica set may already be initialized; continuing." }

docker exec ddb-shard-europe mongosh --port 27018 --quiet --eval 'rs.initiate({_id:"rsEurope",members:[{_id:0,host:"shard-europe:27018"}]})' 2>$null
if ($LASTEXITCODE -ne 0) { Write-Host "Europe replica set may already be initialized; continuing." }

docker exec ddb-shard-usa mongosh --port 27018 --quiet --eval 'rs.initiate({_id:"rsUSA",members:[{_id:0,host:"shard-usa:27018"}]})' 2>$null
if ($LASTEXITCODE -ne 0) { Write-Host "USA replica set may already be initialized; continuing." }

Start-Sleep -Seconds 6

Write-Host "3/7 Starting mongos router..."
docker compose up -d mongos
Wait-ContainerMongo "ddb-mongos" 27017

Write-Host "4/7 Adding the three shards..."
docker exec ddb-mongos mongosh --port 27017 --quiet --file /scripts/03-add-shards.js

Write-Host "5/7 Creating schema..."
docker exec ddb-mongos mongosh --port 27017 --quiet --file /scripts/04-create-schema.js

Write-Host "6/7 Applying fragmentation and inserting demo data..."
docker exec ddb-mongos mongosh --port 27017 --quiet --file /scripts/05-configure-fragmentation.js
docker exec ddb-mongos mongosh --port 27017 --quiet --file /scripts/06-seed-data.js

Write-Host "7/7 Verifying distribution..."
docker exec ddb-mongos mongosh --port 27017 --quiet --file /scripts/07-verify-fragmentation.js

Write-Host ""
Write-Host "DONE."
Write-Host "MongoDB router: mongodb://localhost:27017"
Write-Host "Open shell with:"
Write-Host "docker exec -it ddb-mongos mongosh --port 27017"
