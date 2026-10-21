# Darkly — Prep & Execution Sheet

Oct 21, 2026 · @Lucas

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
| Command injection | Input passed to a shell (ping, lookup, convert tools) | Chain a command with `; id`, \` | id` ,  `$(id)\` or backticks |
| Unrestricted file upload | An upload form with weak or client-side-only checks | Upload a `.php` web shell; bypass filters with `shell.php.jpg`, double extensions, or a fake `Content-Type` | Validate type server-side, rename files, store outside web root, block execution |
| LFI / path traversal | A `page=` or `file=` param that loads a file | `../../../../etc/passwd`, or `php://filter` to read source; `/proc/self/environ` for RCE | Allow-list filenames; never pass user input to `include`/`open` |
| Cross-site scripting (XSS) | Input reflected back into the page (search, comments, profile) | Inject `<script>alert(1)</script>`; if filtered, try attribute/event-handler or encoded variants; steal the admin cookie | Context-aware output encoding; Content-Security-Policy |
| Broken auth / brute force | A login with no lockout, weak/default creds | `hydra` against the login form, or a small wordlist; try `admin/admin` and leaked defaults first | Rate-limit, lockout, strong password policy, MFA |
| Broken access control / IDOR | A resource keyed by a guessable id (`?user=2`, `/profile/5`) | Change the id to reach another user's data or an admin-only page | Enforce authorisation server-side on every object, per request |
| Session & cookie manipulation | A cookie encoding a role, user or privilege | Decode it (base64/hex), flip a value (`admin=0`→`1`), re-sign if the scheme is weak | Server-side sessions; sign/encrypt cookies; never trust client state |
| CSRF | A state-changing form (change password/email) with no anti-CSRF token | Host a page that auto-submits the request against the logged-in victim | Per-request CSRF tokens; `SameSite` cookies |
| Weak password reset | Reset tied to a guessable token or a security question | Predict/brute the token, or answer a weak secret question | High-en