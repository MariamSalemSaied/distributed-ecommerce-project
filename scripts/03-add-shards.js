function addShardIfMissing(name, connectionString) {
  const admin = db.getSiblingDB("admin");
  const existing = admin.runCommand({ listShards: 1 }).shards || [];
  if (!existing.some(s => s._id === name)) {
    print(`Adding ${name}...`);
    printjson(sh.addShard(connectionString));
  } else {
    print(`${name} already exists.`);
  }
}

addShardIfMissing("rsEgypt", "rsEgypt/shard-egypt:27018");
addShardIfMissing("rsEurope", "rsEurope/shard-europe:27018");
addShardIfMissing("rsUSA", "rsUSA/shard-usa:27018");

print("Current shards:");
printjson(db.getSiblingDB("admin").runCommand({ listShards: 1 }));
