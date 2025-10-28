#!/usr/bin/env bash
set -e

PUBLIC="http://localhost:8080"
BLUE_CHAOS="http://localhost:8081/chaos/start?mode=error"
BLUE_CHAOS_STOP="http://localhost:8081/chaos/stop"
POLL_DURATION=10
INTERVAL=0.5

echo "1) Baseline checks: expect 8 x 200 with X-App-Pool: blue"
for i in $(seq 1 8); do
  status=$(curl -s -o /dev/null -w "%{http_code}" "$PUBLIC/version")
  pool=$(curl -sI "$PUBLIC/version" | tr -d '\r' | grep -i '^X-App-Pool:' | awk '{print $2}' | tr -d '[:space:]')
  echo "  attempt $i -> status=$status pool=$pool"
  if [ "$status" -ne 200 ] || [ "$pool" != "blue" ]; then
    echo "Baseline failed on attempt $i: status=$status pool=$pool"
    exit 2
  fi
  sleep 0.2
done
echo "Baseline OK."

echo "2) Trigger chaos on Blue (error mode)"
curl -s -X POST "$BLUE_CHAOS" || true

echo "3) Polling public endpoint for $POLL_DURATION seconds (interval $INTERVAL)"
end=$(( $(date +%s) + POLL_DURATION ))
total=0
non200=0
green_count=0

while [ $(date +%s) -lt $end ]; do
  total=$((total+1))
  status=$(curl -s -o /dev/null -w "%{http_code}" "$PUBLIC/version" || echo "000")
  pool=$(curl -sI "$PUBLIC/version" | tr -d '\r' | grep -i '^X-App-Pool:' | awk '{print $2}' | tr -d '[:space:]' || echo "none")
  echo "  poll #$total -> $status $pool"
  if [ "$status" -ne 200 ]; then
    non200=$((non200+1))
  fi
  if [ "$pool" = "green" ]; then
    green_count=$((green_count+1))
  fi
  sleep $INTERVAL
done

echo "Polling finished: total=$total non200=$non200 green=$green_count"

# check conditions
if [ "$non200" -ne 0 ]; then
  echo "FAIL: observed non-200 responses during failover."
  curl -s -I "$PUBLIC/version" || true
  exit 3
fi

# compute percent green as integer
percent_green=$(( (green_count * 100) / total ))
echo "Percent green = $percent_green%"

if [ "$percent_green" -lt 95 ]; then
  echo "FAIL: green responses <$percent threshold (95%). Got $percent_green%."
  exit 4
fi

echo "4) Stop chaos on Blue"
curl -s -X POST "$BLUE_CHAOS_STOP" || true

echo "VERIFY OK: failover met criteria."
exit 0
