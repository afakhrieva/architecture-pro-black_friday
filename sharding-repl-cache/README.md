# Задание 4. Кеширование

### Состав кластера

- **Config Server**: репликасет из 3 узлов (`configSrv1`, `configSrv2`, `configSrv3`)
- **Shard 1**: репликасет из 3 узлов (`shard1_1`, `shard1_2`, `shard1_3`)
- **Shard 2**: репликасет из 3 узлов (`shard2_1`, `shard2_2`, `shard2_3`)
- **Маршрутизатор mongos**: 1 узел (`mongos_router`)
- **Кэш Redis**: 1 узел (`redis`)
- **API сервис**: `pymongo_api`

![Task1-final-scheme.png](../Task1-drawio/Task1-final-scheme.png)

### Запуск

```bash
docker compose up -d
```

### Автоматическая инициализация

Для быстрой настройки шардирования и репликации выполните:

```bash
sh ./scripts/init-replication.sh
```

### Проверка работоспособности Redis

```bash
docker exec -it redis_cache redis-cli ping
# должно вернуть PONG

# Посмотреть ключи кеша
docker exec -it redis_cache redis-cli KEYS "*"
```

### Запрос /users

```bash
curl -s -o /dev/null -w "Total time: %{time_total}s\n" http://localhost:8080/helloDoc/users
```

### Очистка кэша Redis

```bash
docker exec redis_cache redis-cli FLUSHALL
```

