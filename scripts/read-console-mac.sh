#!/usr/bin/env bash
set -euo pipefail

lines="${1:-240}"
console="$HOME/Zomboid/console.txt"

if [ ! -f "$console" ]; then
  echo "[read-console-mac] console.txt not found: $console"
  exit 1
fi

tail -n "$lines" "$console"
