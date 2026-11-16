# Darkly — Methodology

The audit method behind this repository: how the target is run, how its attack
surface is mapped, the vulnerability classes it is built around, and the tools
used against each. The target is a fixed web application, so the method is
fixed; only the live payloads change.

## The target

Darkly is a deliberately vulnerable web platform shipped as a sealed VirtualBox
appliance (`.ova`). The appliance serves a FastAPI frontend backed by a
PocketBase instance bound to `127.0.0.1:8090`. The platform holds 19
vulnerabilities and hides 10 flags, where a flag is a unique `FLAG{...}` token
that is only readable once the breach protecting it has actually been exploited.

Running the appliance:

1. Import the image: `VBoxManage import Darkly_v2.ova` (or **File → Import
   Appliance** in the GUI).
2. Leave the network adapter on the default **NAT**.
3. Start the VM and wait for the banner. Its sealed console prints the URL where
   the application is served; there is no login to the VM itself.
4. Open `http://localhost:4942` on the host. The NAT forward is automatic.

The image files (`.ova`, `.vmdk`, `.qcow2`) are multi-gigabyte and stay out of
git. The web application is the only target: the VM and its operating system are
out of scope.

## Recon — first moves

Most flags are found by noticing *where* user input reaches the server, then
abusing that point. The attack surface is mapped before any single bug is
tested.

1. **Enumerate inputs.** Every `?page=`, `?id=`, `?search=`, form field and
   cookie is a candidate injection point; each one is recorded.
2. **Read page source** (`Ctrl+U`). HTML comments, hidden fields and
   commented-out code carry hints and sometimes flags.
3. **Check `/robots.txt`** and its disallowed paths — often exactly where the
   interesting pages live.
4. **Map hidden directories** with `gobuster dir` or `dirb`: `/admin`,
   `/backup`, `/.git`, `/signin`, upload folders.
5. **Inspect cookies and headers** in devtools. A cookie encoding a role, a
   flag, or base64/hex of a value is a lead; `Server:` and version strings are
   noted.
6. **Proxy everything** through Burp Suite from the start, so every request is
   logged and replayable.
7. **Keep a running list of leads**, worked worst-first — injection and upload
   before cosmetic bugs.

## Vulnerability playbook

The web-vulnerability classes Darkly is built around, ordered worst-first by
typical severity. Each flag maps to one of these; the method is fixed, the exact
parameters and payloads come from the live application.

| Vulnerability | How to spot it | How to exploit | The fix |
| --- | --- | --- | --- |
| SQL injection | A param that feeds a query (`id`, `search`); errors or changed results on `'` | Break out with `'`, confirm with `' OR 1=1-- -`, then `UNION SELECT` to read other tables | Parameterised queries / prepared statements; never concatenate input |
| Command injection | Input passed to a shell (ping, lookup, convert tools) | Chain a command with `; id`, `\| id`, `$(id)` or backticks | Avoid shelling out; if unavoidable, allow-list and escape args |
| Unrestricted file upload | An upload form with weak or client-side-only checks | Upload a web shell; bypass filters with `shell.php.jpg`, double extensions, or a fake `Content-Type` | Validate type server-side, rename files, store outside web root, block execution |
| LFI / path traversal | A `page=` or `file=` param that loads a file | `../../../../etc/passwd`, or `php://filter` to read source | Allow-list filenames; never pass user input to `include`/`open` |
| Cross-site scripting (XSS) | Input reflected into the page (search, comments, profile) | Inject `<script>…</script>`; try attribute/event-handler or encoded variants; steal a privileged cookie | Context-aware output encoding; Content-Security-Policy |
| Broken auth / brute force | A login with no lockout, weak/default creds | A small wordlist or `hydra` against the login form; try defaults first | Rate-limit, lockout, strong password policy, MFA |
| Broken access control / IDOR | A resource keyed by a guessable id (`?user=2`, `/profile/5`) | Change the id to reach another user's data or an admin-only page | Enforce authorisation server-side on every object, per request |
| Session & cookie manipulation | A cookie encoding a role, user or privilege | Decode it, flip a value, re-sign if the scheme is weak | Server-side sessions; sign/encrypt cookies; never trust client state |
| CSRF | A state-changing form with no anti-CSRF token | A page that auto-submits the request against the logged-in victim | Per-request CSRF tokens; `SameSite` cookies |
| Weak password reset | Reset tied to a guessable token or security question | Predict/brute the token, or answer a weak secret question | High-entropy single-use tokens, short expiry, no secret questions |
| Weak "encryption" | A value that looks encrypted but is just encoded | Recognise base64, hex, ROT13 or a trivial cipher and decode it | Use real crypto; never treat encoding as a secret |
| Open redirect | A `redirect=` / `url=` / `next=` param | Point it at an external site; useful in phishing chains | Allow-list redirect targets; use relative paths |
| Information disclosure | Comments, verbose errors, `.git`, backups, version headers | Read source/comments; dump an exposed `.git`; grep errors for paths | Strip comments/headers, custom error pages, block dotfiles and backups |

## Toolkit

| Tool | What it's for |
| --- | --- |
| Burp Suite (Community) | Intercept, inspect and replay every request; the hub for manual testing |
| Browser devtools | Read source, edit cookies, watch network traffic, tweak requests |
| `hydra` | Brute-forces login forms and other auth |
| `gobuster` / `dirb` | Discovers hidden directories and files |
| `nikto` | Quick scan for known misconfigs and exposed files |
| `curl` | Fires precise requests from the terminal; scriptable |
| `git-dumper` | Reconstructs a source tree from an exposed `/.git` |
| `exiftool` | Reads metadata from downloaded files and images |
| CyberChef | Decodes base64/hex/ROT and spots weak "encryption" quickly |

Exploitation scripts in `scripts/` are hand-written `curl` and shell, not
turn-key scanners, so every step is reproducible and explainable.

## Write-up format

One folder per breach under `writeups/`, each with a `README.md` that documents
the issue the same way:

```markdown
# Flag NN — <Vulnerability class>

**Location:** <URL / parameter / form where it lives>
**Severity:** <Critical | High | Medium | Low>

## Discovery
What in recon pointed here.

## Exploitation
The exact steps and payload, with the request/response.

## Impact
What an attacker gains.

## Remediation
The concrete fix.
```

Flags and findings are numbered in two independent sequences from `01`, because
some breaches yield a unique flag and some do not — that is the only difference
between them.

## Further reading

- [PortSwigger Web Security Academy](https://portswigger.net/web-security) — hands-on labs for SQLi, XSS, access control, file upload and more.
- [OWASP Top 10](https://owasp.org/www-project-top-ten/) — the canonical map of these vulnerability classes.
- [OWASP Web Security Testing Guide](https://owasp.org/www-project-web-security-testing-guide/) — a structured testing methodology.
- [PayloadsAllTheThings](https://github.com/swisskyrepo/PayloadsAllTheThings) — a payload reference when a filter blocks the obvious attempt.
