#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "[validate-wsl] repo: $ROOT"

echo "[validate-wsl] 1/4 git diff --check"
git diff --check

echo "[validate-wsl] 2/4 git diff --stat"
git diff --stat || true

echo "[validate-wsl] 3/4 git diff --name-only"
CHANGED_FILES="$(git diff --name-only)"
printf '%s
' "$CHANGED_FILES"

LUA_FILES="$(printf '%s
' "$CHANGED_FILES" | grep -E '\.lua$' || true)"

if command -v luac >/dev/null 2>&1; then
  echo "[validate-wsl] 4/4 luac syntax check"
  if [ -n "$LUA_FILES" ]; then
    while IFS= read -r file; do
      [ -n "$file" ] || continue
      echo "[validate-wsl] luac -p $file"
      luac -p "$file"
    done <<< "$LUA_FILES"
  else
    echo "[validate-wsl] no changed Lua files"
  fi
elif command -v luac5.4 >/dev/null 2>&1; then
  echo "[validate-wsl] 4/4 luac5.4 syntax check"
  if [ -n "$LUA_FILES" ]; then
    while IFS= read -r file; do
      [ -n "$file" ] || continue
      echo "[validate-wsl] luac5.4 -p $file"
      luac5.4 -p "$file"
    done <<< "$LUA_FILES"
  else
    echo "[validate-wsl] no changed Lua files"
  fi
else
  echo "[validate-wsl] 4/4 Lua parser not available; static checks only"
  echo "[validate-wsl] checked: diff --check, diff --stat, diff --name-only"
fi

echo "[validate-wsl] done"
