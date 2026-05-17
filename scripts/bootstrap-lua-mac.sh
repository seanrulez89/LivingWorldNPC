#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLS_DIR="$ROOT/.tools"
LUA_VERSION="5.1.5"
LUA_DIR="$TOOLS_DIR/lua-$LUA_VERSION"
LUA_ARCHIVE="$TOOLS_DIR/lua-$LUA_VERSION.tar.gz"
LUAC="$LUA_DIR/src/luac"

echo "[bootstrap-lua-mac] repo: $ROOT"

if [ -x "$LUAC" ]; then
  echo "[bootstrap-lua-mac] luac already available: $LUAC"
  "$LUAC" -v
  exit 0
fi

mkdir -p "$TOOLS_DIR"

if [ ! -f "$LUA_ARCHIVE" ]; then
  echo "[bootstrap-lua-mac] downloading Lua $LUA_VERSION"
  curl -fsSL "https://www.lua.org/ftp/lua-$LUA_VERSION.tar.gz" -o "$LUA_ARCHIVE.tmp"
  mv "$LUA_ARCHIVE.tmp" "$LUA_ARCHIVE"
fi

if [ ! -d "$LUA_DIR" ]; then
  echo "[bootstrap-lua-mac] extracting Lua $LUA_VERSION"
  tar -xzf "$LUA_ARCHIVE" -C "$TOOLS_DIR"
fi

echo "[bootstrap-lua-mac] building luac"
if ! make -C "$LUA_DIR" macosx; then
  echo "[bootstrap-lua-mac] macosx target failed; retrying generic target"
  make -C "$LUA_DIR" clean
  make -C "$LUA_DIR" generic
fi

"$LUAC" -v
echo "[bootstrap-lua-mac] ready: $LUAC"
