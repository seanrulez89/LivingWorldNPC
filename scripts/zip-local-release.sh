#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST="$ROOT/dist"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="$DIST/LivingWorldNPCSP-$STAMP.zip"

mkdir -p "$DIST"
cd "$ROOT"

zip -qr "$OUT" 42 common AGENTS.md .codex
echo "[zip-local-release] created: $OUT"
