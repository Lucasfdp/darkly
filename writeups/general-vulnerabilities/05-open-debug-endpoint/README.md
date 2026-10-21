# Finding 05 — Open debug/exfiltration endpoint (`/api/collect`)

**Flag:** none unique (it is the exfil channel for Flags 04 and 05).
**Severity:** Medium (High as an attacker primitive)
**Class:** Debug functionality left in production / improper access control.

## Observation

Source comment: *"wil: left /api/collect up from when I was debugging the bot — it logs whatever you throw at `?c=` and hands it all back on GET."* Confirmed: `GET /api/collect?c=<data>` stores arbitrary data and `GET /api/collect` returns everything collected, unauthenticated.

## Impact

Provides a same-origin exfiltration sink for the stored XSS and SSRF chains — the moderation bot's cookie and the internal config were both stolen by posting them to `/api/collect` and reading them back. Without this endpoint, those attacks would have needed attacker-controlled external infrastructure; it makes them trivial and self-contained.

## Remediation

- Remove debug endpoints from production builds.
- Never provide an open read/write log reachable without authentication.
