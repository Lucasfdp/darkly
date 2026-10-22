#!/usr/bin/env bash
# Shared login helper for Darkly flag scripts.
# Usage: source lib.sh ; darkly_login "$TARGET" jar.txt
set -uo pipefail

darkly_login() {
  local target="$1" jar="$2"
  local resp
  resp=$(curl -s -i -c "$jar" -X POST "http://${target}:4942/login" \
    --data-urlencode "identity=jdoe" --data-urlencode "password=abc123")

  if ! grep -qi '^set-cookie:.*session=' <<<"$resp"; then
    echo "[FATAL] Login did not set a session cookie. Response headers:" >&2
    echo "$resp" | head -20 >&2
    return 1
  fi
  if ! grep -q 'session' "$jar" 2>/dev/null; then
    echo "[FATAL] Cookie jar '$jar' has no session line after login." >&2
    return 1
  fi
  echo "[ok] Logged in as jdoe, session saved to $jar" >&2
  return 0
}
