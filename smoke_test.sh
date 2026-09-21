#!/usr/bin/env bash

set -Eeuo pipefail

API_BASE_URL="${API_BASE_URL:-http://localhost:${API_PORT:-8000}}"
WORKER_TIMEOUT_SECONDS="${WORKER_TIMEOUT_SECONDS:-30}"
job_id=""

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

cleanup() {
  if [[ -n "${job_id}" ]]; then
    docker compose exec -T redis redis-cli DEL "result:${job_id}" >/dev/null 2>&1 || true
    docker compose exec -T redis redis-cli LREM jobs 0 "${job_id}" >/dev/null 2>&1 || true
  fi
}

trap cleanup EXIT

command -v curl >/dev/null 2>&1 || fail "curl is not installed"
command -v docker >/dev/null 2>&1 || fail "Docker is not installed"
docker compose version >/dev/null 2>&1 || fail "Docker Compose is unavailable"

health_response="$(curl --fail --silent --show-error --max-time 5 \
  "${API_BASE_URL}/health")" || fail "API liveness request failed"
[[ "${health_response}" == *'"status":"healthy"'* ]] || \
  fail "API liveness returned an unexpected response: ${health_response}"
echo "PASS: API liveness"

ready_response="$(curl --fail --silent --show-error --max-time 5 \
  "${API_BASE_URL}/ready")" || fail "API readiness request failed"
[[ "${ready_response}" == *'"status":"ready"'* ]] && \
  [[ "${ready_response}" == *'"redis":"connected"'* ]] && \
  [[ "${ready_response}" == *'"postgres":"connected"'* ]] || \
  fail "API readiness returned an unexpected response: ${ready_response}"
echo "PASS: API readiness"

redis_response="$(docker compose exec -T redis redis-cli ping 2>/dev/null | tr -d '\r\n')" || \
  fail "Redis ping command failed"
[[ "${redis_response}" == "PONG" ]] || \
  fail "Redis returned an unexpected response: ${redis_response}"
echo "PASS: Redis connection"

job_id="smoke-$(date +%s)-$$-${RANDOM}"
docker compose exec -T redis redis-cli LPUSH jobs "${job_id}" >/dev/null 2>&1 || \
  fail "Could not add job ${job_id} to Redis"

deadline=$((SECONDS + WORKER_TIMEOUT_SECONDS))
while ((SECONDS < deadline)); do
  result="$(docker compose exec -T redis redis-cli --raw GET "result:${job_id}" 2>/dev/null | tr -d '\r\n')" || true
  if [[ "${result}" == "processed:${job_id}" ]]; then
    echo "PASS: Worker processed job"
    echo "All smoke tests passed"
    exit 0
  fi
  sleep 1
done

fail "Worker did not process ${job_id} within ${WORKER_TIMEOUT_SECONDS} seconds"
