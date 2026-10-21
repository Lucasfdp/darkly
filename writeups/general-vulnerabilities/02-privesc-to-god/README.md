# Finding 02 — Full privilege escalation to `god` (leaked admin creds → PocketBase)

**Flag:** none unique (reaching god re-exposes existing flags rather than a new string).
**Severity:** Critical
**Class:** Privilege escalation / broken access control via a leaked backend credential.

## Chain

The app blocks self-assigning `staff`/`god` (`403 role not assignable`; "Staff and god accounts use 42 SSO"). That check is only at the app layer. The database underneath has no such rule, and its admin credentials leaked.

1. **SSRF (Finding/Flag 05)** made the moderation bot (localhost) fetch `/internal/config`, leaking `pb_admin_email` / `pb_admin_password` for PocketBase.
2. PocketBase (`127.0.0.1:8090`) is not exposed externally, so the bot's XSS was reused to authenticate to its admin API from inside:
   `POST http://127.0.0.1:8090/api/admins/auth-with-password`.
3. With the admin token, patch the user record directly, bypassing the app's role gate:
   `PATCH http://127.0.0.1:8090/api/collections/users/records/<id>  {"role":"god"}`.
4. Re-requesting `/staff` now shows role `god`; `/admin` opens.

## Note — the real gate is a `level` field (DB-only)

Reaching `god` opens `/admin` but mints no new flag. The admin "Gate" column and the `Staff campus < Staff 42Network < Staff 42` tiers are driven by a numeric `level` field on the user record (jdoe `1.42`, sophie `42`, anne-sophie `-42`). `level` is **not** in `/api/docs-internal`'s `writable_fields`, so the app rejects it — but like `role` it is writable directly in PocketBase. Setting `{"role":"god","level":42}` reaches the top tier and still only re-exposes existing flags, confirming no distinct `staff`/`god` page reward exists in this build.

## Impact

Complete compromise. An attacker reaches the highest role and full database control (read/modify every record), defeating the app's role gating entirely because the data layer trusts anyone with the (leaked) admin password.

## Remediation

- Never store backend admin credentials where the app can be induced to fetch them; rotate the leaked PocketBase admin password.
- Lock down the PocketBase admin API (network isolation, strong unique password, IP allow-list) and never reuse it from request-handling code.
- Enforce authorisation at the data layer, not only in the web app.
