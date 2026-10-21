# Finding 01 — Open redirect

**Flag:** none observed (vulnerability confirmed; no unique flag string returned).
**Location:** `GET /redirect?next=` — used by the footer links and the fake "42 SSO / Google" button.
**Severity:** Low–Medium
**Class:** Open redirect (unvalidated redirect).

## Discovery

The login page's "SSO" button is `/redirect?next=https://accounts.google.com` — the redirect takes an arbitrary `next` URL.

## Exploitation

```bash
curl -s -i "http://TARGET:4942/redirect?next=https://evil.example.com" | grep -i '^location'
# -> HTTP/1.1 307 Temporary Redirect
# -> location: https://evil.example.com
```

The server forwards to any external URL without validation.

## Impact

An attacker can craft a trustworthy-looking link on the real domain that silently sends victims to a phishing or malware site — effective because the fake "Sign in with Google" button already routes through it. Useful as the opening move of a credential-phishing chain.

## Remediation

- Allow-list permitted redirect targets, or only accept relative paths.
- If external redirects are required, show an interstitial warning and never auto-forward to an unvetted host.
