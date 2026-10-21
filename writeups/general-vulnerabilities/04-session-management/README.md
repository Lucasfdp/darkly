# Finding 04 — Session management weaknesses

**Flag:** none unique (the non-httpOnly cookie is what makes Flag 04's XSS steal the session).
**Severity:** Medium–High
**Class:** Insecure session handling.

## Observations

- **Session cookie is not `HttpOnly`** — the staff status page states `Session cookie: httponly=false`, and the stored-XSS (Flag 04) read it from `document.cookie`. It carries `SameSite=Lax` (verified in the live `Set-Cookie`) but has **no `Secure` flag**.
- **Session fixation** — the login console logs `[AUTH] Session fixation window: cookie set without rotation post-login`: the session identifier is not rotated after authentication, so a pre-set session id remains valid once the victim logs in.
- **Forgeable JWT** — see Finding 06 (weak JWT secret).
- **CSRF — tested, not exploitable** (see note below).

## Impact

A non-httpOnly cookie turns any XSS into full session theft (demonstrated). Lack of rotation after login enables session-fixation attacks where an attacker fixes a known session id and inherits the victim's authenticated session.

## CSRF — tested, not exploitable

State-changing `PATCH /api/profile` (the mass-assignment sink, Flag 02) was probed for CSRF. **Not exploitable from a browser**, blocked by two independent controls:

- **`SameSite=Lax`** on the session cookie — not attached to a cross-site `fetch`/XHR `PATCH`, so a forged request arrives unauthenticated.
- **JSON-only endpoint** — a form-encoded body returns `422`; only `application/json` is accepted. A cross-site HTML `<form>` cannot send JSON, forcing a CORS-preflighted `fetch`. The `OPTIONS` preflight returns **no `Access-Control-Allow-Origin`**, so the browser blocks the call.

**Defence-in-depth gaps (log, but not a live vuln):** there is **no CSRF token** on the form and **no server-side `Origin`/`Referer` validation (fail-open)** — the `PATCH` returned `200` in all three cases: a foreign `Origin: evil.example.com`, *no* `Origin`/`Referer` at all, and a spoofed trusted `Origin`. Protection rests **solely** on `SameSite=Lax`. Any regression (a state change reachable via top-level GET, or a cookie switched to `SameSite=None`) would re-open CSRF. Recommend adding a per-session CSRF token and an `Origin` allow-list as a second layer.

## Remediation

- Set `HttpOnly`, `Secure`, and `SameSite=Lax/Strict` on session cookies.
- Rotate (regenerate) the session identifier on every privilege change, especially at login.
