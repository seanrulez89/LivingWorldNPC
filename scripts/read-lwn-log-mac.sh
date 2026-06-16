#!/usr/bin/env bash
set -euo pipefail

lines="${1:-600}"
pattern="${2:-\\[LWN\\]}"
console="$HOME/Zomboid/console.txt"

if [ ! -f "$console" ]; then
  echo "[read-lwn-log-mac] console.txt not found: $console"
  exit 1
fi

grep -E "$pattern" "$console" | tail -n "$lines"
