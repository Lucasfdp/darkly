# Finding 04 — Session management weaknesses

**Flag:** none unique (the non-httpOnly cookie is what makes Flag 04's XSS steal the session).
**Severity:** Medium–High
**Class:** Insecure session handling.

## Observations

- **Session cookie is not `HttpOnly`** — the staff status page states `Session cookie: httponly=false`, and the stored-XSS (Flag 04) read it from `document.cookie`. It is also not `Secure`/`SameSite`.
- **Session fixation** — the login console logs `[AUTH] Session fixation window: cookie set without rotation post-login`: the session identifier is not rotated after authentication, so a pre-set session id remains valid once the victim logs in.
- **Forgeable JWT** — see Finding 06 (weak JWT secret).

## Impact

A non-httpOnly cookie turns any XSS into full session theft (demonstrated). Lack of rotation after login enables session-fixation attacks where an attacker fixes a known session id and inherits the victim's authenticated session.

## Remediation

- Set `HttpOnly`, `Secure`, and `SameSite=Lax/Strict` on session cookies.
- Rotate (regenerate) the session identifier on every privilege change, especially at login.
