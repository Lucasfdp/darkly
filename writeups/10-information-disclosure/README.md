# Finding 10 — Pervasive information disclosure

**Flag:** none unique (these leaks enable the other flags rather than being one).
**Severity:** Medium (High in aggregate — this is what makes the whole box solvable)
**Class:** Information disclosure.

## What leaks, and where

- **HTML source comments** on `/`, `/projects`, `/staff`, `/forum`, `/reset-password`: the JWT secret history (`"42"` → `"42network"`), MD5 password storage, the mass-assignment hint, `/api/docs-internal`, `/api/collect`, the unsanitised download, and the non-httpOnly moderation-bot cookie.
- **Debug response headers** on every response: `x-pocketbase: http://localhost:8090`, `x-42-internal: campus=paris`, `x-powered-by`, exact `server` version.
- **`/api/docs-internal`** (no staff check): the user collection's writable fields and valid `role_values`.
- **`/backup`** headers: backup destination and `x-backup-exclude: data/private_notes.txt`.
- **404 page**: lists `/staff`, `/backup`, `/internal/config`, `/_/`.
- **Deploy-log comment**: admits the JWT secret and unfixed issues.

## Impact

Individually minor, together they hand an attacker the entire attack map and several secrets — secret, hashing scheme, internal endpoints, schema and file paths — turning blind testing into a guided tour.

## Remediation

- Strip all comments, debug headers (`x-pocketbase`, `x-42-internal`, `x-powered-by`, version strings) and verbose errors from production responses.
- Require authorisation on schema/debug endpoints; remove them from production.
- Don't advertise internal paths in `robots.txt`/404 pages.
