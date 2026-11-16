# darkly

## 📖 About

**darkly** is a web-penetration audit of a deliberately vulnerable platform: a
**FastAPI** frontend backed by a **PocketBase** instance bound to
`127.0.0.1:8090`, served from a sealed VirtualBox appliance at
`http://localhost:4942`. The platform holds **19 vulnerabilities** and hides
**10 flags** — a flag being a unique `FLAG{...}` token readable only once the
breach protecting it has actually been exploited.

This repository is the full audit: **all 10 flags recovered** and **17 issues
documented** — the 10 flagged breaches plus 7 further findings that carry no
flag of their own. Each issue is written up with its discovery, exploitation,
impact and remediation, and the chained flags ship a hand-written reproduction
script built from plain `curl` and shell, never a turn-key scanner.

The breaches span the OWASP web classes: broken authentication, mass-assignment
and broken access control, IDOR, stored and reflected XSS, SSRF, path traversal,
weak password reset, unrestricted upload, CSRF, information disclosure and a weak
JWT secret. Several only fall when chained together — stored XSS drives a
localhost bot, the bot performs SSRF, the SSRF leaks backend credentials, and
those credentials take over the database.

The combined audit document is in
[docs/README.md](docs/README.md); the method behind it — target setup, recon,
the vulnerability playbook and the toolkit — is in
[docs/methodology.md](docs/methodology.md).

## 🎯 Objectives

- Map the attack surface of an unknown web application from recon alone
- Recover 10 flags, 4 of them by escalating privileges step by step to
  administrator
- Chain independent weaknesses — XSS → SSRF → credential leak → database takeover
- Separate the application-layer access checks from the datastore that never
  enforces them
- Document every breach with its impact and the concrete remediation
- Reproduce each chained flag from a self-contained, explainable script

## 📋 Flags & Findings

<details>
<summary><strong>Flags (10 of 10) and general vulnerabilities (7)</strong></summary>

<br>

Write-ups live under `writeups/`, in two sequences each numbered independently
from `01`: `flags/` (breaches that yield a flag) and `general-vulnerabilities/`
(findings with no flag).

### Flags

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

### General vulnerabilities

| # | Vulnerability | Severity |
| --- | --- | --- |
| 01 | Open redirect (`/redirect?next=`) | Low–Medium |
| 02 | Full privilege escalation to `god` (leaked admin creds → DB role patch) | Critical |
| 03 | Pervasive information disclosure (comments, debug headers, internal docs, backups) | Medium (High aggregate) |
| 04 | Session management (cookie not HttpOnly, session fixation) | Medium–High |
| 05 | Open debug/exfil endpoint (`/api/collect`) | Medium |
| 06 | Weak / leaked JWT signing secret (`42network`) | High |
| 07 | Reflected XSS — `/newsletter` `email` echoed unescaped | Medium |

<br>

</details>

<details>
<summary><strong>Privilege ladder & attack chains</strong></summary>

<br>

The role ladder is `visitor` < `student` < `cadet` < `staff` < `god`. Four flags
are won by climbing it to administrator:

- `01` authenticate as a student (weak password)
- `02` self-promote student → cadet (mass assignment)
- `05` SSRF leaks the PocketBase admin credentials — the step that unlocks
  staff/god
- `08` use those credentials on the PocketBase admin UI → the administrator tier

Reaching `staff`/`god` mints no page flag of its own: access is gated by a
database-only numeric `level` field, and the climb is a leaked-credential →
database takeover.

```
Flag 04  stored XSS ──> drives the localhost moderation bot
                            │
Flag 05  SSRF ──────────────┴─> bot reads /internal/config ──> PocketBase admin creds
                                                                     │
Finding 02  ───────────────────── bot authenticates to PocketBase ──┴─> PATCH role=god
Flag 08   ─────────────────────── same creds on admin UI /_/ ──────────> internal_audit
```

The application's "role not assignable" and "SSO only" checks are app-layer
only; the PocketBase database underneath enforces no such rule, so writing
`role` directly in the datastore bypasses them. The session JWT is forgeable
(secret `42network`), but the app re-reads `role` from the database, so a forged
claim does not help — the database must be changed.

<br>

</details>

<details>
<summary><strong>Running the audit</strong></summary>

<br>

### Target

The platform is a sealed VirtualBox appliance (`.ova`). Import it, leave the
adapter on the default **NAT**, and start it; its console prints the served URL.
With NAT the application is reachable from the host at `http://localhost:4942`.
The image files stay out of git. Setup details are in
[docs/methodology.md](docs/methodology.md#the-target).

### Reproduction scripts

`scripts/` holds hand-written reproduction scripts for the chained flags. The
target host defaults to `localhost` and is overridden with the `TARGET`
environment variable.

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

<br>

</details>

<details>
<summary><strong>Repository Structure</strong></summary>

<br>

```
darkly/
│
├── README.md                          # Project overview
│
├── docs/
│   ├── README.md                      # Combined audit document
│   └── methodology.md                 # Target setup, recon, vuln playbook, toolkit
│
├── scripts/
│   ├── 02-mass-assignment-privesc.sh  # Flag 02
│   ├── 04-stored-xss.sh               # Flag 04
│   ├── 05-ssrf-internal-config.sh     # Flag 05
│   ├── 06-path-traversal.sh           # Flag 06
│   ├── 10-csrf-no-origin-check.sh     # Flag 10
│   ├── run-all.sh                     # Runs the chained flag scripts
│   └── lib.sh                         # Shared helpers
│
└── writeups/
    ├── README.md                      # Index of the two write-up sequences
    ├── GOD-STAFF-ESCALATION.md        # Role-escalation runbook
    │
    ├── flags/                         # 10 breaches that yield a flag
    │   ├── 01-weak-password/
    │   ├── 02-mass-assignment-privesc/
    │   ├── 03-idor-profile/
    │   ├── 04-stored-xss/
    │   ├── 05-ssrf-internal-config/
    │   ├── 06-path-traversal/
    │   ├── 07-weak-password-reset/
    │   ├── 08-pocketbase-internal-audit/
    │   ├── 09-unrestricted-upload/
    │   └── 10-csrf-no-origin-check/
    │
    └── general-vulnerabilities/       # 7 findings with no flag
        ├── 01-open-redirect/
        ├── 02-privesc-to-god/
        ├── 03-information-disclosure/
        ├── 04-session-management/
        ├── 05-open-debug-endpoint/
        ├── 06-weak-jwt-secret/
        └── 07-reflected-xss-newsletter/
```

Each write-up folder holds a `README.md` documenting the breach: location,
severity, discovery, exploitation, impact and remediation.

<br>

</details>

## 💡 Key Learning Outcomes

- **The OWASP web classes** in practice: authentication, access control,
  injection, XSS, SSRF, CSRF, file upload and information disclosure
- **Chaining**: how a low-impact bug becomes critical once linked to the next —
  XSS into SSRF into credential leak into full database takeover
- **Trust boundaries**: why an access check enforced only in the application
  layer is worthless when the datastore enforces none
- **Server-side request forgery**: reaching a localhost-only service by driving a
  component that can already talk to it
- **Credential hygiene**: how one leaked backend password collapses an entire
  privilege model
- **Reproducibility**: building exploits as self-contained scripts that explain
  every request instead of hiding behind a scanner

## ⚙️ Technical Specifications

- **Target**: FastAPI frontend + PocketBase backend (`127.0.0.1:8090`), served at
  `http://localhost:4942` from a VirtualBox NAT appliance
- **Surface**: 19 vulnerabilities, 10 flags; 17 issues documented (10 flags + 7
  findings)
- **Role model**: `visitor` < `student` < `cadet` < `staff` < `god`, with
  `staff`/`god` gated by a database-only `level` field
- **Exploits**: hand-written `curl`/shell, host selected by the `TARGET`
  environment variable
- **Documentation**: one Markdown write-up per breach, two independent `01`-based
  sequences

## 🔧 Requirements

- VirtualBox to import and run the `.ova` appliance
- `bash` and `curl` to run the reproduction scripts
- A browser and, optionally, an intercepting proxy for manual testing

The audit method and toolkit are detailed in
[docs/methodology.md](docs/methodology.md).

---

> [!NOTE]
> Every flag here is proof that a breach really works: the token is unreadable
> until the vulnerability behind it has been exploited. The hardest ones fall
> only to a chain — no single bug reaches `god`, but four of them in sequence do.
