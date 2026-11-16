# Darkly

## Description

Darkly is a web-penetration audit of a deliberately vulnerable platform: a
FastAPI frontend backed by a PocketBase instance bound to `127.0.0.1:8090`,
served from a sealed VirtualBox appliance at `http://localhost:4942`. The
platform holds 19 vulnerabilities and hides 10 flags, where a flag is a unique
`FLAG{...}` token readable only once the breach protecting it has been
exploited.

This repository documents the full audit: all 10 flags recovered and 17 issues
written up — the 10 flagged breaches plus 7 further findings that carry no flag
of their own. Each issue is documented with its discovery, exploitation, impact
and remediation, and the flagged breaches ship a hand-written reproduction
script under `scripts/`.

The audit method — how the appliance is run, how the attack surface is mapped,
the vulnerability classes involved and the tools used — is in
[methodology.md](methodology.md).

## Results

Write-ups live under `writeups/`, split into two groups, each numbered
independently from `01`:

- `writeups/flags/` — breaches that yield a unique flag.
- `writeups/general-vulnerabilities/` — real weaknesses that carry no flag; they
  enable the flagged ones or stand as findings in their own right.

Cross-references name the group (for example "Flag 02" versus "Finding 02")
because the two sequences reuse the same numbers.

### Flags (10 of 10)

| # | Flag | Vulnerability | Severity |
| --- | --- | --- | --- |
| 01 | `FLAG{md5_1s_4_n4m3pl4t3_n0t_4_l0ck}` | Weak password (dictionary) + unsalted MD5 | High |
| 02 | `FLAG{just_p4tch_y0ur_0wn_r0l3_lol}` | Mass-assignment privilege escalation (`role`) | Critical |
| 03 | `FLAG{1d0r_ur_pr0f1l3_1s_m1n3}` | IDOR on profile pages | High |
| 04 | `FLAG{xss_st0r3d_1s_n0t_4_f34tur3_w1l}` | Stored XSS → bot cookie theft | Critical |
| 05 | `FLAG{d3fus3dxml_n3xt_spr1nt_pr0m1s3}` | SSRF via bot → internal config leak | Critical |
| 06 | `FLAG{d0t_d0t_sl4sh_4ll_th3_w4y_d0wn}` | Path traversal / arbitrary file read | High |
| 07 | `FLAG{r3s3t_t0k3n_w4s_just_md5_lol}` | Weak password reset — predictable `md5(email)` token | High |
| 08 | `FLAG{th3_und3rsc0r3_sl4sh_kn0ws_th3_w4y}` | Exposed PocketBase admin UI → `internal_audit` | Critical |
| 09 | `FLAG{unr3str1ct3d_upl0ad_g0_brrr}` | Unrestricted file upload (avatar) | High |
| 10 | `FLAG{csrf_4ny_0r1g1n_1s_w3lc0m3}` | CSRF — no `Origin`/`Referer` check on settings | High |

### General vulnerabilities (7)

| # | Vulnerability | Severity |
| --- | --- | --- |
| 01 | Open redirect (`/redirect?next=`) | Low–Medium |
| 02 | Full privilege escalation to `god` (leaked PocketBase admin creds → DB role patch) | Critical |
| 03 | Pervasive information disclosure (comments, debug headers, internal docs, backups) | Medium (High aggregate) |
| 04 | Session management (cookie not HttpOnly, session fixation) | Medium–High |
| 05 | Open debug/exfil endpoint (`/api/collect`) | Medium |
| 06 | Weak / leaked JWT signing secret (`42network`) | High |
| 07 | Reflected XSS — `/newsletter` `email` echoed unescaped | Medium |

## Privilege ladder

The role ladder is `visitor` < `student` < `cadet` < `staff` < `god`. Four flags
are won by climbing it to administrator, step by step:

- `01` authenticate as a student (weak password);
- `02` self-promote student → cadet (mass assignment);
- `05` SSRF leaks the PocketBase admin credentials — the step that unlocks
  staff/god;
- `08` use those credentials on the PocketBase admin UI → the administrator tier.

Reaching `staff`/`god` mints no page flag of its own: access is gated by a
database-only numeric `level` field (see
[general-vulnerabilities/02](../writeups/general-vulnerabilities/02-privesc-to-god)),
and the climb is the leaked-credential → database takeover above. The remaining
flags (`03`, `04`, `06`, `07`, `09`, `10`) are independent breaches across IDOR,
stored XSS, path traversal, weak reset, unrestricted upload and CSRF.

## Key chains

- **To `god`:** stored XSS (Flag 04) drives the localhost moderation bot → SSRF
  reads `/internal/config` (Flag 05) → leaked PocketBase admin credentials →
  authenticate to PocketBase from the bot → `PATCH role=god` on the own record
  (Finding 02). The app-layer "role not assignable" / "SSO only" checks never
  reach the database, which has no such rule.
- **Leaked credentials, two payoffs:** the `/internal/config` JSON (Flag 05)
  exposes the PocketBase admin password. Relayed to the PocketBase API via the
  bot it escalates roles (Finding 02); used against the admin UI at `/_/` it
  opens the database console directly and exposes the `internal_audit` flag
  (Flag 08).
- **Account takeover:** emails follow `username@student.42.tech`; the reset token
  is `md5(email)` with no validation, and the recovery code carries the flag
  (Flag 07).

## Reproduction scripts

`scripts/` holds hand-written reproduction scripts for the chained flags. They
are plain `curl` and shell — no turn-key scanners — so every request is
explainable. The target host defaults to `localhost` and can be overridden with
the `TARGET` environment variable.

```bash
cd scripts
TARGET=localhost ./run-all.sh          # runs the chained flag scripts in sequence
TARGET=localhost ./04-stored-xss.sh    # or a single breach
```

| Script | Breach |
| --- | --- |
| `02-mass-assignment-privesc.sh` | Flag 02 — self-promote `role` student → cadet |
| `04-stored-xss.sh` | Flag 04 — stored XSS → bot cookie theft |
| `05-ssrf-internal-config.sh` | Flag 05 — SSRF via bot → internal config leak |
| `06-path-traversal.sh` | Flag 06 — arbitrary file read |
| `10-csrf-no-origin-check.sh` | Flag 10 — CSRF on `POST /profile/me/settings` |
| `run-all.sh` | Runs the five scripts above in order |
| `lib.sh` | Shared helpers sourced by the scripts |

The remaining flags are documented with their requests inline in each
`writeups/` folder.

## Repository layout

```
darkly/
├── README.md                       # Project overview
├── docs/
│   └── methodology.md              # Target setup, recon, vuln playbook, toolkit
├── scripts/                        # Hand-written reproduction scripts
└── writeups/
    ├── README.md                   # Index of the two write-up sequences
    ├── GOD-STAFF-ESCALATION.md
    ├── flags/                      # 10 breaches that yield a flag
    └── general-vulnerabilities/    # 7 findings with no flag
```

## Resources

- [OWASP Top 10](https://owasp.org/www-project-top-ten/) — the vulnerability classes audited.
- [OWASP Web Security Testing Guide](https://owasp.org/www-project-web-security-testing-guide/) — testing methodology.
- [PortSwigger Web Security Academy](https://portswigger.net/web-security) — labs for each class.
- [PayloadsAllTheThings](https://github.com/swisskyrepo/PayloadsAllTheThings) — payload reference.
- [PocketBase](https://pocketbase.io/) — the backend the platform is built on.
