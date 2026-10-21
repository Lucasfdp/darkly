# Finding 07 — Reflected XSS (newsletter confirmation banner)

**Flag:** none observed (vulnerability confirmed; no unique flag string returned).
**Location:** `POST /newsletter` → redirect to `GET /newsletter?email=<value>&msg=subscribed`. The `email` value is echoed unescaped into the "subscribed with: …" confirmation banner.
**Severity:** Medium (reflected; requires the victim to open a crafted link).
**Class:** Reflected cross-site scripting — user input reflected into HTML without output encoding.

## Discovery

The newsletter sign-up (`/newsletter`, field `email`, plain `type="text"` with no validation) stores nothing security-relevant, but on submit it 302-redirects to `/newsletter?email=<submitted>&msg=subscribed` and renders a banner: `subscribed with: <email>`. Source comments on the page admit the flaw outright:

```html
<!-- wil: the "subscribed with: ___" banner echoes your email straight back. sophie: unescaped?? wil: define "unescaped". -->
<!-- emilie: someone subscribed with a <script> tag last week. wil: bold of them. it worked. -->
```

## Exploitation

The `email` parameter is reflected verbatim — HTML is not encoded:

```bash
TARGET=192.168.1.155
loc=$(curl -s -o /dev/null -w '%{redirect_url}' -b jdoe.txt -X POST "http://$TARGET:4942/newsletter" \
  --data-urlencode "email=pwn<b>X</b>@t.com")
curl -s -b jdoe.txt "$loc" | grep -o 'subscribed with: pwn<b>X</b>'
# -> subscribed with: pwn<b>X</b>   (tag rendered, not escaped)
```

The banner is driven by the `?email=` query parameter, so a full payload (`...?email=<script>…</script>&msg=subscribed`) executes in the victim's browser when they open the link — a classic reflected-XSS delivery.

## Impact

An attacker crafts a link on the real domain that runs arbitrary script in a victim's session when clicked — session/cookie theft, actions as the victim, or a phishing overlay. Distinct from the stored forum XSS (Flag 04): this one needs no moderation bot, only a clicked link, and reflects on a trusted path.

## Remediation

- HTML-escape all reflected values (the banner `email`) on output; use the template engine's autoescaping rather than raw interpolation.
- Validate the `email` field server-side (format + length) and do not echo arbitrary input back.
- Add a Content-Security-Policy that blocks inline script as defence in depth.

## Note

No flag is emitted by this path; it reflects to the requester's own browser, and driving the moderation bot to it would only re-yield the Flag 04 cookie. Recorded as a standalone finding toward the platform's vulnerability count.
