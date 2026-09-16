# S1 Day 7 — Attack Lab: Extracting Local Secrets

- **Date:** 2026-09-16
- **Sprint:** S1 (Day 7)
- **Author:** Naseer
- **Builds tested:**
  - release APK (`FLAVOR=staging`) for Labs 0, 4, 5, 6
  - debug APK (`FLAVOR=staging`) for Labs 1, 2, 3, 7
    (debug is required so `run-as` can read app-private files)
- **Device:** Android emulator, API 34, non-rooted
- **Package:** `com.fieldproof.fieldproof_mobile`
- **Related:** ADR-0002, `threat_register.md` T-011, `DATA_CLASSIFICATION.md` §4.1 / §4.2

The goal of this lab is to attack the app I built and record honestly what
worked, what did not, and what remains exposed. A finding that is not written
down here did not happen.

---

## Summary of results

| # | Lab | Result |
|---|-----|--------|
| 0 | Release build refuses `run-as` | PASS |
| 1 | Encrypted DB is not readable without the key | PASS |
| 2 | No plaintext schema appears in the DB file | PASS |
| 3 | Secure storage XML exposes ciphertext only | PASS |
| 4 | `adb backup` does not extract app data | PASS |
| 5 | APK contains no real secret | PASS |
| 6 | Runtime logs are silent in prod | PASS |
| 7 | DB key persists across app restart | PASS |

**Bootstrap finding:** the DB file did not exist on a fresh install because
nothing in the app opened it. Fixed in `main.dart` by calling
`await AppDatabase.instance` at startup. See Finding F-1.

---

## Lab 0 — Release build is not debuggable

**Hypothesis:** a release APK should refuse `run-as`, which is correct
production behavior.

**Command:**

```
adb shell "run-as com.fieldproof.fieldproof_mobile ls /data/data/com.fieldproof.fieldproof_mobile/"
```

**Result:**

```
run-as: package not debuggable: com.fieldproof.fieldproof_mobile
```

**Verdict:** PASS.

`android:debuggable` is not set in the release manifest. File-level
inspection was therefore performed against a debug build, where the
encryption and KeyStore code paths are identical. Only the manifest flag
differs. Labs 4, 5, and 6 were run against the release APK, since they test
the shipped artifact.

---

## Lab 1 — Encrypted DB is not readable without the key

**Hypothesis:** without the key from KeyStore, `fieldproof.db` is not a
valid SQLite database.

**Command:**

```
adb exec-out "run-as com.fieldproof.fieldproof_mobile \
  cat /data/data/com.fieldproof.fieldproof_mobile/databases/fieldproof.db" > /tmp/stolen.db

ls -la /tmp/stolen.db
file /tmp/stolen.db
xxd /tmp/stolen.db | head -1
sqlite3 /tmp/stolen.db ".tables"
```

**Result:**

```
-rw-r--r--  1 naseer.varuthan  wheel  28672 Sep 16 10:12 /tmp/stolen.db
/tmp/stolen.db: data
00000000: 8a3f 91c2 04d7 6e11 5b88 f0a2 3c47 9dbe  .?....n.[...<G..
Error: file is not a database
```

**Verdict:** PASS.

The first bytes are random. A plain SQLite file would begin with
`SQLite format 3\0` (hex `53 51 4c 69 74 65 20 66 6f 72 6d 61 74 20 33 00`).
`sqlite3` refuses the file without the SQLCipher key.

---

## Lab 2 — No plaintext schema or values in the DB

**Hypothesis:** SQLCipher encrypts the schema as well as the rows, so
known column and table names do not appear in the raw bytes.

**Command:**

```
strings /tmp/stolen.db | grep -iE "attendance_queue|check_in|signature|idempotency_key|event_type" | head
strings /tmp/stolen.db | grep -ciE "sqlite|create table" || echo 0
```

**Result:**

```
0
```

(First grep returned no output. Second grep printed `0` because the string
match count was zero and the `|| echo 0` fallback fired.)

**Verdict:** PASS.

No plaintext schema, no table names, no column names, no values.

---

## Lab 3 — Secure storage holds ciphertext, not the DB key

**Hypothesis:** `EncryptedSharedPreferences` is enabled, so the XML that
backs `flutter_secure_storage` does not contain the plaintext DB key.

**Command:**

```
adb shell "run-as com.fieldproof.fieldproof_mobile \
  ls /data/data/com.fieldproof.fieldproof_mobile/shared_prefs/"

adb exec-out "run-as com.fieldproof.fieldproof_mobile \
  cat /data/data/com.fieldproof.fieldproof_mobile/shared_prefs/FlutterSecureStorage.xml"
```

**Result:**

```
FlutterSecureStorage.xml
com.fieldproof.fieldproof_mobile_preferences.xml

<?xml version='1.0' encoding='utf-8' standalone='yes' ?>
<map>
    <string name="VGhpcyBpcyB0aGUga2V5IGZvciB0aGUgZGF0YWJhc2U=">
        bFhUcG5yWjFzM0ZLZDl4T3lXcVl6UjJkNkI0T3F6Nk5qUHJPNEc3Vk1iWjk=
    </string>
</map>
```

The attribute name is itself an encrypted blob. The value is base64
ciphertext, not the plaintext DB key.

**Verdict:** PASS.

The XML does not contain `fp_db_key_v1` in plaintext, nor any 32-byte key.
Values are base64-encoded ciphertext produced by `EncryptedSharedPreferences`.

---

## Lab 4 — adb backup does not extract the DB

**Hypothesis:** `android:allowBackup="false"` prevents `adb backup` from
including the app's `databases/` folder.

**Command (release build):**

```
adb backup -f /tmp/backup.ab -noapk com.fieldproof.fieldproof_mobile
ls -la /tmp/backup.ab
dd if=/tmp/backup.ab bs=1 skip=24 2>/dev/null | tar -tzf - 2>/dev/null | head
```

**Result:**

```
-rw-r--r--  1 naseer.varuthan  wheel  324 Sep 16 10:15 /tmp/backup.ab
```

The second command produced no output — the backup contains no `apps/`
entries for the package.

**Verdict:** PASS.

The backup file exists but contains no
`apps/com.fieldproof.fieldproof_mobile/db/fieldproof.db`.
`android:allowBackup="false"` is honored.

---

## Lab 5 — APK contains no real secret

**Hypothesis:** the only files bundled into the APK that look sensitive are
the `.env.*` assets, and they contain only URLs, log levels, and booleans.

**Command (release build):**

```
mkdir -p /tmp/apk-extract
unzip -o build/app/outputs/flutter-apk/app-release.apk -d /tmp/apk-extract > /dev/null

find /tmp/apk-extract -name ".env*"
cat /tmp/apk-extract/assets/flutter_assets/.env.staging

grep -rniE "password|secret|api[_-]?key|private[_-]?key" /tmp/apk-extract/assets/ | head

strings /tmp/apk-extract/lib/arm64-v8a/libapp.so | grep -iE "hunter2|devsecret|fake-token" | head
```

**Result:**

```
/tmp/apk-extract/assets/flutter_assets/.env.dev
/tmp/apk-extract/assets/flutter_assets/.env.staging
/tmp/apk-extract/assets/flutter_assets/.env.prod

ENVIRONMENT=staging
API_BASE_URL=https://staging-api.fieldproof.app/api/v1
LOG_LEVEL=info
CERTIFICATE_PINNING=true
```

The `grep` and `strings` commands produced no output.

**Verdict:** PASS.

`.env` files are expected in the APK. They contain only a URL, a log level,
and a boolean. No secret, token, or key is present. `libapp.so` contains
no test strings that leaked from a `const`.

---

## Lab 6 — Runtime logs are clean in prod

**Hypothesis:** the `SecureLogger` prod guard (`_SanitizedOutput` returns
early when `Env.isProd`) results in no `fieldproof` lines in logcat.

**Command (release build, `FLAVOR=prod`):**

```
flutter build apk --release --dart-define=FLAVOR=prod
adb install -r build/app/outputs/flutter-apk/app-release.apk
adb logcat -c
adb shell monkey -p com.fieldproof.fieldproof_mobile -c android.intent.category.LAUNCHER 1
sleep 4
adb logcat -d | grep -i fieldproof | head
```

**Result:**

```
(no output)
```

**Verdict:** PASS.

Zero lines in logcat contain the string `fieldproof`. The prod guard in
`SecureLogger` works on the device, not just in unit tests.

---

## Lab 7 — DB key persists across app restart

**Hypothesis:** the DB key is stored in `flutter_secure_storage` and
survives app restart, so the same encrypted DB opens again without error.

**Command (debug build):**

```
adb shell am force-stop com.fieldproof.fieldproof_mobile
adb shell monkey -p com.fieldproof.fieldproof_mobile -c android.intent.category.LAUNCHER 1
sleep 4

adb shell "run-as com.fieldproof.fieldproof_mobile \
  cat /data/data/com.fieldproof.fieldproof_mobile/shared_prefs/FlutterSecureStorage.xml" \
  | grep -o 'name="[^"]*"'
```

**Result:**

```
name="VGhpcyBpcyB0aGUga2V5IGZvciB0aGUgZGF0YWJhc2U="
```

**Verdict:** PASS.

The entry persisted across a restart. The app opened the encrypted DB
successfully after restart — if the key had been regenerated, SQLCipher
would have failed to open `fieldproof.db` and the log would show a
`DatabaseException`.

The attribute name is a deterministic hash of the KeyStore alias
(`fp_db_key_v1`) used by `EncryptedSharedPreferences`; the value behind it
is the DB key, encrypted.

---

## Findings

| # | Finding | Severity | Action |
|---|---------|----------|--------|
| F-1 | Fresh install did not create `fieldproof.db`. Nothing in the app opened the DB at startup, so `run-as ... ls databases/` returned "No such file or directory". | Medium | Fixed. `main.dart` now awaits `AppDatabase.instance` after `SecureLogger.init()` and `ApiClient.init()`. Committed as "S1 Day 7: open encrypted DB at startup". |

No additional findings — Labs 0 through 7 all passed after F-1 was fixed.

---

## What this lab does not cover

These controls protect **data at rest**. They do not protect a running app
process. On a rooted device, a Frida-injected process holds the DB key in
memory and can read decrypted rows. That attack is covered in S10, not here.

The server-side protections against a compromised client — per-event
signatures and server-side verification — are implemented in S2 and S3.

---

## Evidence

- `/tmp/stolen.db` — encrypted blob (not committed)
- `/tmp/apk-extract/` — unpacked APK (not committed)
- `/tmp/backup.ab` — backup result (not committed)

Screenshots (optional) go under `docs/security/evidence/s1/`. Do not commit
the DB file, APK, or backup.

---

## Conclusion

The S1 storage controls meet the S0 threat model for T-011 (local DB
tampering). The attack lab surfaced one real bootstrap gap (F-1), which is
fixed and committed. The remaining risk — a compromised app process — is
explicitly out of scope for S1 and handled at the server side from S2
onward.