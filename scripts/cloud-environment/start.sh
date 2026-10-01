#!/usr/bin/env bash
set -euo pipefail
cd /workspace/redis
runtime_dir=/workspace/redis-onboarding/runtime
mkdir -p "$runtime_dir"
if [ -f "$runtime_dir/redis.pid" ] && kill -0 "$(cat "$runtime_dir/redis.pid")" 2>/dev/null; then
  test "$(readlink "/proc/$(cat "$runtime_dir/redis.pid")/exe")" = /workspace/redis/src/redis-server
else
  ./src/redis-server --bind 127.0.0.1 --port 16379 --protected-mode yes \
    --daemonize yes --pidfile "$runtime_dir/redis.pid" \
    --logfile "$runtime_dir/redis.log" --dir "$runtime_dir" \
    --save '' --appendonly no
fi
for attempt in {1..30}; do
  if [ "$(./src/redis-cli -h 127.0.0.1 -p 16379 ping 2>/dev/null)" = PONG ]; then
    echo 'Redis ready on loopback port 16379'
    exit 0
  fi
  sleep 0.2
done
cat "$runtime_dir/redis.log" >&2
exit 1
