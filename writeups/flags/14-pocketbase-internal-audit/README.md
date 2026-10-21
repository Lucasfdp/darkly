# Flag 14 — PocketBase admin UI exposed → `internal_audit` collection

**Flag:** `FLAG{th3_und3rsc0r3_sl4sh_kn0ws_th3_w4y}`
**Location:** PocketBase admin dashboard at `/_/` (port `8090`); the flag sits in the `internal_audit` collection, readable once logged in.
**Severity:** Critical
**Class:** Broken access control / sensitive data exposure — backend admin console reachable with leaked credentials.

## Access chain

The credentials used here are the same `pb_admin_email` / `pb_admin_password` that leaked as JSON from `GET /internal/config` via the moderation-bot SSRF (see [../05-ssrf-internal-config](../05-ssrf-internal-config)):

```json
{"pb_admin_email":"admin@42network.local",
 "pb_admin_password":"Darkly42Admin!", ...}
```

Earlier escalation (Finding 09) relayed those creds to the PocketBase *API* through the bot because the backend was treated as localhost-only. This flag is reached a simpler way: the PocketBase **admin web UI** was browsable directly.

## Discovery & exploitation

1. The `x-pocketbase` debug header and the 404 page both advertise the backend and the `/_/` path (the PocketBase admin dashboard). The flag name — "the underscore-slash knows the way" — points straight at `/_/`.
2. Open the admin UI in a browser:

   ```
   http://TARGET:8090/_/#/
   ```
3. Log in with the leaked JSON credentials (`admin@42network.local` / `Darkly42Admin!`).
4. The dashboard lists all collections. Alongside the app collections there is an **`internal_audit`** collection; opening it reveals the flag record:

   ```
   FLAG{th3_und3rsc0r3_sl4sh_kn0ws_th3_w4y}
   ```

No bot relay or XSS was needed — the admin console answered directly on the LAN IP and accepted the leaked password.

## Impact

Direct, interactive, full control of the database: read and modify every collection and record, export data, change schema, and alter any user's role — all through a point-and-click console, authenticated by a password that the app itself leaked. This is strictly worse than the API-only path, because it needs no exploit primitive at all once the creds are known.

## Remediation

- **Rotate** the leaked PocketBase admin password immediately; treat it as fully compromised.
- Do **not** expose the PocketBase admin UI (`/_/`) to the network — bind it to localhost and reach it only over an SSH tunnel, or put it behind an IP allow-list / VPN.
- Stop leaking the backend's existence and path (`x-pocketbase` header, the 404 path list) — see [../../general-vulnerabilities/10-information-disclosure](../../general-vulnerabilities/10-information-disclosure).
- Never store backend admin credentials in an app-reachable endpoint (`/internal/config`).

## Related

- [05 — SSRF / internal config leak](../05-ssrf-internal-config) — where the admin creds leaked.
- [09 — privesc to god](../../general-vulnerabilities/09-privesc-to-god) — same creds, relayed to the PocketBase API via the bot.
