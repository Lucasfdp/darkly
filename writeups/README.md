# Darkly — vulnerability write-ups

Web-pentest of the 42 "Darkly" platform (FastAPI + PocketBase rebuild). Each folder documents one issue: discovery, exploitation, impact, and remediation. Target IP is written as `TARGET`.

Write-ups are split into two groups, **each numbered independently from 01**:

- **`flags/`** — issues that yield a unique `FLAG{...}`.
- **`general-vulnerabilities/`** — real weaknesses that don't carry their own flag (they enable the flagged ones or are graded as findings).

## `flags/` — captured (9)

| # | Flag | Vulnerability | Severity |
| --- | --- | --- | --- |
| 01 | `FLAG{md5_1s_4_n4m3pl4t3_n0t_4_l0ck}` | Weak password (dictionary) + unsalted MD5 | High |
| 02 | `FLAG{just_p4tch_y0ur_0wn_r0l3_lol}` | Mass-assignment privilege escalation (`role`) | Critical |
| 03 | `FLAG{1d0r_ur_pr0f1l3_1s_m1n3}` | IDOR on profile pages | High |
| 04 | `FLAG{xss_st0r3d_1s_n0t_4_f34tur3_w1l}` | Stored XSS → bot cookie theft | Critical |
| 05 | `FLAG{d3fus3dxml_n3xt_spr1nt_pr0m1s3}` | SSRF via bot → internal config leak (also the XXE/defusedxml objective) | Critical |
| 06 | `FLAG{d0t_d0t_sl4sh_4ll_th3_w4y_d0wn}` | Path traversal / arbitrary file read | High |
| 07 | `FLAG{r3s3t_t0k3n_w4s_just_md5_lol}` | Weak password reset — predictable `md5(email)` recovery token, account takeover | High |
| 08 | `FLAG{th3_und3rsc0r3_sl4sh_kn0ws_th3_w4y}` | PocketBase admin UI (`/_/`) exposed; leaked creds → `internal_audit` collection | Critical |
| 09 | `FLAG{unr3str1ct3d_upl0ad_g0_brrr}` | Unrestricted file upload — avatar accepts any file type (uploaded `main.c`) | High |

## `general-vulnerabilities/` — findings, no unique flag (7)

| # | Vulnerability | Severity |
| --- | --- | --- |
| 01 | Open redirect (`/redirect?next=`) | Low–Medium |
| 02 | Full privilege escalation to `god` (leaked PocketBase admin creds → DB role patch) | Critical |
| 03 | Pervasive information disclosure (comments, debug headers, docs-internal, backups) | Medium (High aggregate) |
| 04 | Session management (cookie not HttpOnly, session fixation) | Medium–High |
| 05 | Open debug/exfil endpoint (`/api/collect`) | Medium |
| 06 | Weak / leaked JWT signing secret (`42network`) | High |
| 07 | Reflected XSS — `/newsletter` `email` echoed unescaped in the confirmation banner | Medium |

> Each group is numbered independently from 01. Cross-references name the group explicitly (e.g. "Flag 02" vs "Finding 02") because the two sequences reuse the same numbers.

## Flag map — mandatory vs bonus (9 of 10 found)

The subject hides **10 flags**: 6 mandatory (4 won by escalating privilege to administrator, 2 of free choice) + 4 bonus.

**Privilege ladder — the 4 mandatory privesc flags** (visitor → student → cadet → admin):
- `01` authenticate as a student (weak password)
- `02` self-promote student → cadet (mass assignment)
- `05` SSRF leaks the PocketBase admin credentials — the step that unlocks staff/god
- `08` use those creds on the PocketBase admin UI → the administrator tier

Reaching `staff`/`god` in the app mints no page flag of its own: access is gated by a DB-only numeric `level` field (see [general-vulnerabilities/02](general-vulnerabilities/02-privesc-to-god)); the climb to administrator is the leaked-cred → DB takeover above.

**Two of your choice** (any 2): `03` IDOR, `04` stored XSS, `06` path traversal, `07` weak reset, `09` unrestricted upload.

**Bonus:** 9 of 10 recovered. The 10th is still open: every input surface tested clean — login, forum search (parameterised), newsletter (reflected XSS, no flag — Finding 07), agenda import (XXE hardened — Flag 05), file download (= Flag 06), avatar upload (= Flag 09) — and content discovery found no hidden routes. The last flag likely needs a larger wordlist or a vector outside common content-discovery.


## Key chains

- **To `god`:** stored XSS (Flag 04) → drive the localhost bot → SSRF read `/internal/config` (Flag 05) → leaked PocketBase admin creds → authenticate to PocketBase from the bot → `PATCH role=god` on own record (Finding 02). The app's "role not assignable" / "SSO only" checks are app-layer only; the database had no such rule.
- **Leaked creds, two payoffs:** the `/internal/config` JSON (Flag 05) exposes the PocketBase admin password. Relayed to the PocketBase *API* via the bot it escalates roles (Finding 02); used against the admin *UI* at `/_/` it opens the database console directly and exposes the `internal_audit` flag (Flag 08).
- **Account takeover:** emails follow `username@student.42.tech`; reset token is `md5(email)` with no validation, and the recovery code carries the flag (Flag 07).

## Still open (next session)

- One privilege-ladder flag still missing: the reward for reaching `staff`/`god` in the app. `/api/docs-internal` shows no scope field (role maxes at `god`, already held) and `/admin` exposes only jdoe's L1 grade flag — so it is not a settable gate. Cadet sees Flag 02 on `/staff`, but `staff`/`god` see no flag there (the request likely 302s). Capture `/staff` and `/admin` as `god` following redirects, inspecting response headers and `Set-Cookie` (cf. the moderation-bot flag cookie), and check `/static/js/console_eggs.js`.

## Method notes

Recon-first (robots.txt, HTML comments, `/api/docs-internal`, console `darkly42.*`, gobuster), then exploited worst-first. All testing done against a local lab VM.
