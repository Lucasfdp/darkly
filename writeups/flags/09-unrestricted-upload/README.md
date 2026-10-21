# Flag 09 — Unrestricted file upload (avatar)

**Flag:** `FLAG{unr3str1ct3d_upl0ad_g0_brrr}`
**Location:** Profile settings → avatar upload (the `avatar` file field). Uploading a non-image file (e.g. a `.c` source file) is accepted instead of being rejected, and the flag is returned.
**Severity:** High (Critical if the upload directory is served executable).
**Class:** Unrestricted file upload — no content-type / extension / magic-byte validation on a user-supplied file.

## Discovery

The staff status page advertised `File uploads: Enabled (unrestricted)`, but earlier content-discovery never located a storing sink. It turned out the sink is the ordinary **avatar upload** on the profile settings page — it takes whatever you give it. robots.txt disallows `/static/uploads/`, which is where uploaded files land.

## Exploitation

1. Go to profile settings and choose a file for the avatar.
2. Instead of an image, upload a source file — `main.c` was used.
3. The server accepts the non-image file (no type check) and returns the flag:

```
FLAG{unr3str1ct3d_upl0ad_g0_brrr}
```

No image signature, extension allow-list, or size/type gate is enforced — any file type is stored.

## Impact

Accepting arbitrary file types is dangerous in proportion to what the storage location allows. At minimum it enables stored malicious content (HTML/SVG → stored XSS, oversized files → DoS). If `/static/uploads/` (or the PocketBase `users.avatar` file field's served path) executes or serves uploads with an attacker-controlled content-type, this escalates to arbitrary file serving and potentially remote code execution — a full server compromise from an avatar field.

## Remediation

- Validate uploads server-side: allow-list image MIME types **and** verify magic bytes; reject anything else. Never trust the client-supplied filename or `Content-Type`.
- Re-encode accepted images (strip metadata, normalise to a safe format) rather than storing the raw upload.
- Store uploads outside the web root, serve them from a separate domain with a fixed, non-executable `Content-Type`, and generate server-side filenames.
- Enforce a size limit and rate-limit the endpoint.

## In simple terms

The site let you set a profile picture. It was supposed to accept only images — but it never actually checked. We handed it a C source file (`main.c`) instead of a photo, and it happily took it and coughed up the flag. A photo upload that accepts *any* file is a classic way in: depending on where the file ends up, an attacker can plant a booby-trapped page or even code the server will run. Lesson: an upload box must check *what* it's being given, not just that something arrived.
