#!/usr/bin/env bash
# Runs all 5 remaining flag scripts in sequence.
set -uo pipefail
TARGET="${TARGET:-localhost}"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export TARGET
for s in 02-mass-assignment-privesc 06-path-traversal 10-csrf-no-origin-check 04-stored-xss 05-ssrf-internal-config; do
  echo "===== $s ====="
  "$DIR/$s.sh"
  echo
done
