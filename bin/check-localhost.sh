#!/usr/bin/env bash
# Check if localhost services are reachable on given ports.
# Usage: check-localhost.sh <port> [port...]
# Each port may optionally include a path: 44369/api/health
#
# Output: JSON array with one object per port:
#   [{"port":44369,"url":"https://localhost:44369","status":200,"reachable":true}, ...]
#
# Exit code: 0 if ALL ports are reachable (2xx), 1 if any are not.

set -euo pipefail

if [ $# -eq 0 ]; then
  echo "Usage: check-localhost.sh <port>[/path] [port][/path] ..." >&2
  exit 2
fi

all_reachable=true
results="["
first=true

for arg in "$@"; do
  port="${arg%%/*}"
  path="${arg#*/}"
  [ "$path" = "$arg" ] && path=""

  # Use HTTPS for well-known SSL ports: 443, 8443, IIS Express range (44300-44399)
  if [ "$port" -eq 443 ] 2>/dev/null || [ "$port" -eq 8443 ] 2>/dev/null || \
     { [ "$port" -ge 44300 ] 2>/dev/null && [ "$port" -le 44399 ] 2>/dev/null; }; then
    url="https://localhost:${port}"
  else
    url="http://localhost:${port}"
  fi

  [ -n "$path" ] && url="${url}/${path}"

  status=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 2 --max-time 5 --insecure "$url" 2>/dev/null) || true
  [ -z "$status" ] && status="000"

  if [ "$status" -ge 200 ] 2>/dev/null && [ "$status" -lt 400 ] 2>/dev/null; then
    reachable=true
  else
    reachable=false
    all_reachable=false
  fi

  if [ "$first" = true ]; then
    first=false
  else
    results="${results},"
  fi

  results="${results}{\"port\":${port},\"url\":\"${url}\",\"status\":${status},\"reachable\":${reachable}}"
done

results="${results}]"

echo "$results"

if [ "$all_reachable" = true ]; then
  exit 0
else
  exit 1
fi
