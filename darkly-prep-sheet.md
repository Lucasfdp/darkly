# Darkly — Prep & Execution Sheet

Your execution sheet for the Darkly web-pentesting project: the vulnerability classes the app is built around, how to find and exploit each, and how to log them — so the cluster session is hunting, not setup. Darkly is a fixed target, so everything except the live payloads can be prepared in advance.

## Cluster setup (do this first)

On a native x86 machine (any 42 cluster box), VirtualBox runs this image with zero of tonight's pain. The image is built for VirtualBox NAT, so `localhost:4942` just works.

1. Get `Darkly_v2.ova` onto the machine — clone your repo, carry it on a USB stick, or re-download: `wget -c http://cdn.intra.42.fr/isos/Darkly_v2.ova`
2. Import it: `VBoxManage import Darkly_v2.ova` (or **File → Import Appliance** in the GUI).
3. Leave the network adapter on the default **NAT** — do not change it.
4. Start the VM and wait for the banner.
5. Open `http://localhost:4942` in the cluster machine's browser. The NAT forward is automatic.

Keep the `.ova`, `.vmdk` and `.qcow2` out of git — they're multi-GB and will bloat the repo or be rejected by GitHub.

## Recon — first moves

Before testing any single bug, map the whole app. Most Darkly flags are found by noticing *where* user input reaches the server, then abusing that point. Spend the first 15 minutes here.

1. **Click every link and note every parameter.** Each `?page=`, `?id=`, `?search=`, form field or cookie is a candidate injection point. Write them down.
2. **Read the page source** on each page (`Ctrl+U`). HTML comments, hidden fields and commented-out code hide hints and sometimes flags.
3. **Check `/robots.txt`** and any paths it disallows — those are often exactly where the interesting pages live.
4. **Map hidden directories** with `gobuster dir -u http://localhost:4942 -w <wordlist>` (or `dirb`). Look for `/admin`, `/backup`, `/.git`, `/signin`, upload folders.
5. **Inspect cookies and headers** in devtools. A cookie that looks like a flag, a role, or base64/hex of something is a lead. Note the `Server:` header and any version strings.
6. **Proxy everything through Burp Suite** from the start, so every request is logged and replayable. You'll re-fire the same request dozens of times with tweaks.
7. **Keep a running list of leads** — one line per suspicious input point — and work them worst-first (injection and upload before cosmetic bugs).

## Vulnerability playbook

These are the web-vulnerability classes Darkly is built around, ordered worst-first by typical severity. Each flag maps to one of these; the exact parameters and payloads come from the live app, but the method below is fixed. For each flag, Darkly expects you to find it, exploit it, **and** state the remediation — so log all three.

| Vulnerability | How to spot it | How to exploit | The fix |
| --- | --- | --- | --- |
| SQL injection | A param that feeds a query (`id`, `search`); errors or changed results on `'` | Break out with `'`, confirm with `' OR 1=1-- -`, then `UNION SELECT` to read other tables; or let `sqlmap` do it | Parameterised queries / prepared statements; never concatenate input |
| Command injection | Input passed to a shell (ping, lookup, convert tools) | Chain a command with `; id`, `\| id`, `$(id)` or backticks | Avoid shelling out; if unavoidable, allow-list and escape args |
| Unrestricted file upload | An upload form with weak or client-side-only checks | Upload a `.php` web shell; bypass filters with `shell.php.jpg`, double extensions, or a fake `Content-Type` | Validate type server-side, rename files, store outside web root, block execution |
| LFI / path traversal | A `page=` or `file=` param that loads a file | `../../../../etc/passwd`, or `php://filter` to read source; `/proc/self/environ` for RCE | Allow-list filenames; never pass user input to `include`/`open` |
| Cross-site scripting (XSS) | Input reflected back into the page (search, comments, profile) | Inject `<script>alert(1)</script>`; if filtered, try attribute/event-handler or encoded variants; steal the admin cookie | Context-aware output encoding; Content-Security-Policy |
| Broken auth / brute force | A login with no lockout, weak/default creds | `hydra` against the login form, or a small wordlist; try `admin/admin` and leaked defaults first | Rate-limit, lockout, strong password policy, MFA |
| Broken access control / IDOR | A resource keyed by a guessable id (`?user=2`, `/profile/5`) | Change the id to reach another user's data or an admin-only page | Enforce authorisation server-side on every object, per request |
| Session & cookie manipulation | A cookie encoding a role, user or privilege | Decode it (base64/hex), flip a value (`admin=0`→`1`), re-sign if the scheme is weak | Server-side sessions; sign/encrypt cookies; never trust client state |
| CSRF | A state-changing form (change password/email) with no anti-CSRF token | Host a page that auto-submits the request against the logged-in victim | Per-request CSRF tokens; `SameSite` cookies |
| Weak password reset | Reset tied to a guessable token or a security question | Predict/brute the token, or answer a weak secret question | High-entropy single-use tokens, short expiry, no secret questions |
| Weak "encryption" | A value that looks encrypted but is just encoded | Recognise base64, hex, ROT13 or a trivial cipher and decode it | Use real crypto; never treat encoding as a secret |
| Open redirect | A `redirect=` / `url=` / `next=` param | Point it at an external site to confirm; useful for phishing chains | Allow-list redirect targets; use relative paths |
| Information disclosure | Comments, verbose errors, `.git`, backups, version headers | Read source/comments; dump an exposed `.git` with `git-dumper`; grep errors for paths | Strip comments/headers, custom error pages, block dotfiles and backups |

**Flag count:** check the subject PDF for how many flags the version you have expects, and tick each class off against it — some versions skip a class or include two of the same type.

## Toolkit

Most cluster machines have these or can install them. Burp plus a browser covers 80% of Darkly; the rest fill gaps.

| Tool | What it's for |
| --- | --- |
| Burp Suite (Community) | Intercept, inspect and replay every request; the hub for manual testing |
| Browser devtools | Read source, edit cookies, watch network traffic, tweak requests |
| `sqlmap` | Automates SQL injection detection and data extraction |
| `hydra` | Brute-forces login forms and other auth |
| `gobuster` / `dirb` | Discovers hidden directories and files |
| `nikto` | Quick scan for known misconfigs and exposed files |
| `curl` | Fire precise requests from the terminal; scriptable |
| `git-dumper` | Reconstructs a source tree from an exposed `/.git` |
| `exiftool` | Reads metadata from downloaded files/images |
| CyberChef (web) | Decode base64/hex/ROT and spot weak "encryption" quickly |

## Per-flag log template

One folder per breach, each with a `README.md` from this template. Fill it as you go — it doubles as your repo write-up and your proof of understanding for evaluation.

```markdown
# Flag NN — <Vulnerability class>

**Location:** <URL / parameter / form where it lives>
**Severity:** <Critical | High | Medium | Low>

## Discovery
How I found it — what in recon pointed here.

## Exploitation
The exact steps and payload used, with the request/response.
(Redact the literal flag value if sharing publicly.)

## Impact
What an attacker gains from this.

## Remediation
The concrete fix (parameterised query, output encoding, etc.).
```

Suggested repo layout: `01-sql-injection/`, `02-command-injection/`, `03-file-upload/` … each holding its `README.md` plus any screenshots or scripts.

## Further reading

Study the method against these while you wait for the cluster. The PortSwigger Academy is the single best resource — free, hands-on labs for most classes above.

- [PortSwigger Web Security Academy](https://portswigger.net/web-security) — labs for SQLi, XSS, access control, file upload and more
- [OWASP Top 10](https://owasp.org/www-project-top-ten/) — the canonical map of these vulnerability classes
- [OWASP Web Security Testing Guide](https://owasp.org/www-project-web-security-testing-guide/) — a structured testing methodology
- [PayloadsAllTheThings](https://github.com/swisskyrepo/PayloadsAllTheThings) — a payload reference for when a filter blocks the obvious attempt
