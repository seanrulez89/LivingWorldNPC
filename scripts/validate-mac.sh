#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "[validate-mac] repo: $ROOT"

echo "[validate-mac] 1/6 mod structure"
required=(
  "42"
  "42/mod.info"
  "42/media"
  "42/media/lua"
  "common"
  "AGENTS.md"
  ".codex/config.toml"
)

missing=()
for item in "${required[@]}"; do
  if [ ! -e "$ROOT/$item" ]; then
    missing+=("$item")
  fi
done

if [ "${#missing[@]}" -gt 0 ]; then
  echo "[validate-mac] missing required paths:"
  printf ' - %s\n' "${missing[@]}"
  exit 1
fi

echo "[validate-mac] 2/6 git diff --check"
git diff --check

echo "[validate-mac] 3/6 git diff --stat"
git diff --stat || true

echo "[validate-mac] 4/6 git status --short"
git status --short

echo "[validate-mac] 5/6 git diff --name-only"
git diff --name-only

echo "[validate-mac] 6/6 Lua syntax"
luac_bin="${LUAC:-}"
if [ -z "$luac_bin" ] && [ -x "$ROOT/.tools/lua-5.1.5/src/luac" ]; then
  luac_bin="$ROOT/.tools/lua-5.1.5/src/luac"
fi
if [ -z "$luac_bin" ]; then
  luac_bin="$(command -v luac || true)"
fi
if [ -z "$luac_bin" ]; then
  luac_bin="$(command -v luac5.1 || true)"
fi
if [ -z "$luac_bin" ]; then
  luac_bin="$(command -v luac5.4 || true)"
fi

if [ -z "$luac_bin" ]; then
  echo "[validate-mac] luac not found."
  echo "[validate-mac] Run: bash scripts/bootstrap-lua-mac.sh"
  exit 1
fi

echo "[validate-mac] using: $luac_bin"
while IFS= read -r file; do
  [ -n "$file" ] || continue
  echo "[validate-mac] luac -p $file"
  "$luac_bin" -p "$file"
done < <(find 42 common -type f -name '*.lua' | sort)

echo "[validate-mac] done"
