#!/bin/bash
set -e

echo "=== 0. Ожидание готовности контейнеров ==="
sleep 5

echo "=== 1. Инициализация Config Server ==="
docker exec -it configSrv mongosh --port 27017 --eval "
  rs.initiate({
    _id: 'config_server',
    configsvr: true,
    members: [{ _id: 0, host: 'configSrv:27017' }]
  })
"

echo "=== 2. Инициализация шарда 1 ==="
docker exec -it shard1 mongosh --port 27018 --eval "
  rs.initiate({
    _id: 'shard1',
    members: [{ _id: 0, host: 'shard1:27018' }]
  })
"

echo "=== 3. Инициализация шарда 2 ==="
docker exec -it shard2 mongosh --port 27019 --eval "
  rs.initiate({
    _id: 'shard2',
    members: [{ _id: 0, host: 'shard2:27019' }]
  })
"

echo "=== Ожидание выбора primary (10 сек) ==="
sleep 10

echo "=== 4. Добавление шардов в маршрутизатор ==="
docker exec -it mongos_router mongosh --port 27020 --eval "
  sh.addShard('shard1/shard1:27018');
  sh.addShard('shard2/shard2:27019');
"

echo "=== 5. Включение шардирования для базы данных и коллекции ==="
docker exec -it mongos_router mongosh --port 27020 --eval "
  sh.enableSharding('somedb');
  sh.shardCollection('somedb.helloDoc', { _id: 'hashed' });
"

echo "=== 6. Проверка после инициализации ==="

docker exec -it shard1 mongosh --port 27018 --eval "rs.status()"
docker exec -it shard2 mongosh --port 27019 --eval "rs.status()"
docker exec -it mongos_router mongosh --port 27020 --eval "sh.status()"

echo "=== 7. Заполнение базы тестовыми данными ==="
docker exec -it mongos_router mongosh --port 27020 --eval "
  db = db.getSiblingDB('somedb');
  for (var i = 0; i < 1000; i++) {
    db.helloDoc.insertOne({ age: i, name: 'ly' + i });
  }
  print('Inserted ' + db.helloDoc.countDocuments() + ' documents');
"

echo "=== 8. Проверка распределение данных по шардам ==="
docker exec -it mongos_router mongosh --port 27020 --eval "
  db = db.getSiblingDB('somedb');
  var stats = db.helloDoc.getShardDistribution();
  if (stats) {
    printjson(stats);
  } else {
    print('Метод getShardDistribution не сработал, проверяем вручную:');
  }
"

echo "=== 9. Ручная проверка количества документов на каждом шарде ==="
echo "Документов на shard1:"
docker exec -it shard1 mongosh --port 27018 --eval "db.getSiblingDB('somedb').helloDoc.countDocuments()"
echo "Документов на shard2:"
docker exec -it shard2 mongosh --port 27019 --eval "db.getSiblingDB('somedb').helloDoc.countDocuments()"

echo "=== Инициализация завершена ==="