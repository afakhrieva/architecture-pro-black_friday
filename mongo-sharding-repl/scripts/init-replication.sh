#!/bin/bash
set -e

echo "=== 1. Инициализация Config Server Replica Set ==="
docker exec configSrv1 mongosh --port 27017 --eval "
  rs.initiate({
    _id: 'configReplSet',
    configsvr: true,
    members: [
      { _id: 0, host: 'configSrv1:27017' },
      { _id: 1, host: 'configSrv2:27017' },
      { _id: 2, host: 'configSrv3:27017' }
    ]
  })
"

echo "=== 2. Инициализация Shard 1 Replica Set ==="
docker exec shard1_1 mongosh --port 27018 --eval "
  rs.initiate({
    _id: 'shard1ReplSet',
    members: [
      { _id: 0, host: 'shard1_1:27018' },
      { _id: 1, host: 'shard1_2:27018' },
      { _id: 2, host: 'shard1_3:27018' }
    ]
  })
"

echo "=== 3. Инициализация Shard 2 Replica Set ==="
docker exec shard2_1 mongosh --port 27019 --eval "
  rs.initiate({
    _id: 'shard2ReplSet',
    members: [
      { _id: 0, host: 'shard2_1:27019' },
      { _id: 1, host: 'shard2_2:27019' },
      { _id: 2, host: 'shard2_3:27019' }
    ]
  })
"

echo "=== Ожидание выбора primary (15 сек) ==="
sleep 15

echo "=== 4. Добавление шардов в маршрутизатор ==="
docker exec mongos_router mongosh --port 27020 --eval "
  sh.addShard('shard1ReplSet/shard1_1:27018,shard1_2:27018,shard1_3:27018');
  sh.addShard('shard2ReplSet/shard2_1:27019,shard2_2:27019,shard2_3:27019');
"

echo "=== 5. Включение шардирования для базы данных и коллекции ==="
docker exec mongos_router mongosh --port 27020 --eval "
  sh.enableSharding('somedb');
  sh.shardCollection('somedb.helloDoc', { _id: 'hashed' });
"

echo "=== 6.1 Проверка после инициализации configSrv1 Status ==="
docker exec configSrv1 mongosh --port 27017 --eval "rs.status()"

echo "=== 6.2 Проверка после инициализации shard1_1 Status ==="
docker exec shard1_1 mongosh --port 27018 --eval "rs.status()"

echo "=== 6.3 Проверка после инициализации shard2_1 Status ==="
docker exec shard2_1 mongosh --port 27019 --eval "rs.status()"

echo "=== 6.4 Проверка после инициализации mongos_router Status ==="
docker exec mongos_router mongosh --port 27020 --eval "sh.status()"

echo "=== 7. Заполнение базы тестовыми данными ==="
docker exec mongos_router mongosh --port 27020 --eval "
  db = db.getSiblingDB('somedb');
  for (var i = 0; i < 1000; i++) {
    db.helloDoc.insertOne({ age: i, name: 'ly' + i });
  }
  print('Inserted ' + db.helloDoc.countDocuments() + ' documents');
"

echo "=== 8. Проверка распределение данных по шардам ==="
docker exec mongos_router mongosh --port 27020 --eval "
  db = db.getSiblingDB('somedb');
  var stats = db.helloDoc.getShardDistribution();
  if (stats) {
    printjson(stats);
  } else {
    print('Метод getShardDistribution не сработал, проверяем вручную:');
  }
"

echo "=== 9. Ручная проверка количества документов на каждом шарде ==="
echo "Документов на shard1_1:"
docker exec shard1_1 mongosh --port 27018 --eval "db.getSiblingDB('somedb').helloDoc.countDocuments()"
echo "Документов на shard2_1:"
docker exec shard2_1 mongosh --port 27019 --eval "db.getSiblingDB('somedb').helloDoc.countDocuments()"

echo "=== Инициализация завершена ==="