# Flag 06 — Path traversal / arbitrary file read

**Flag:** `FLAG{d0t_d0t_sl4sh_4ll_th3_w4y_d0wn}`
**Location:** `GET /projects/download?file=` — the `file` parameter is joined to a base directory without sanitisation.
**Severity:** High
**Class:** Path traversal (directory traversal) → arbitrary file read within the app root.

## Discovery

Source comments on `/projects` admitted it: *"/projects/download serves any file you ask for"* and *"joins paths without sanitizing"*. The `/backup` response header `x-backup-exclude: data/private_notes.txt` named a file worth reading. Legitimate downloads (`faq_darkly.pdf`, `norm_v4.pdf`) confirmed the endpoint reads from a resources directory.

## Exploitation

The endpoint has a partial filter, mapped by probing:
- System keywords (`etc`, `passwd`), absolute paths, and multiple `../` → `403 forbidden` (a containment check).
- A single `../` is allowed and resolves within the app root → either the file, or `not found`.

So one `../` reaches the parent of the resources directory, where the note lives:

```bash
TARGET=192.168.1.155
curl -s -b jdoe.txt "http://$TARGET:4942/projects/download?file=../private_notes.txt"
```

Returns:

```
# 42 Network — internal ops note (NOT for the public webroot) — wil
# reminder: rotate the pb_admin password after the security audit. (we won't.)
# emilie keeps saying /projects/download joins paths without sanitizing. it's fine.
recovery_flag=FLAG{d0t_d0t_sl4sh_4ll_th3_w4y_d0wn}
```

### Notes on the filter

The block-list approach is weak: it denies known-bad tokens (`etc/passwd`, deep `../`) but still permits one `../`, which is enough to climb out of the intended resources directory and read sibling files.

## Impact

Any authenticated user can read files outside the intended download directory. Here it exposed an internal ops note (and a reminder that the database admin password is never rotated). A stricter base or a readable source/config file would leak secrets directly.

## Remediation

- Never join user input into a filesystem path. Resolve the final path and verify it stays within the intended directory (`os.path.realpath` must start with the base), rejecting anything that doesn't.
- Prefer an allow-list: map requested names to a fixed set of permitted files/ids rather than accepting arbitrary paths.
- Do not rely on a deny-list of bad substrings — one permitted `../` defeats it.
