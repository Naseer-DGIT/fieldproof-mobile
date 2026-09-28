# S5 — Mobile SQLCipher Rekey

- **Date:** 2026-09-24
- **Sprint:** S5 (Day 6)
- **Author:** Naseer
- **Related:** ADR-0002, ADR-0004

---

## What

The SQLCipher database key rotates every 90 days. The rekey is a
five-step operation that survives a crash at any point.

Three aliases in KeyStore:

| Alias | Purpose |
|-------|---------|
| `fp_db_key_v1` | The key currently in use |
| `fp_db_key_next_v1` | A key that was written but not yet promoted |
| `fp_db_key_prev_v1` | The key that was just replaced, kept for one open cycle |

## Procedure

1. Generate a new key.
2. Write it to `fp_db_key_next_v1`.
3. Run `PRAGMA rekey = 'newKey'`.
4. Copy the old key to `fp_db_key_prev_v1`.
5. Copy the new key to `fp_db_key_v1`.
6. Delete `fp_db_key_next_v1` and `fp_db_key_prev_v1`.

## Recovery on next open

The open path tries three aliases in order:

1. `fp_db_key_v1` — normal case.
2. `fp_db_key_next_v1` — a rekey completed but the promotion did not.
   On success, promote `next` to `primary` and clear the rest.
3. `fp_db_key_prev_v1` — a promotion happened but the DB was not
   rekeyed. On success, demote `prev` back to `primary`.

If all three fail, the DB is unreadable. The app logs
`db.unrecoverable` and throws. Recovery from that state is a
re-registration.

## Why `prev` exists

The window between step 3 (DB rekeyed) and step 5 (primary updated) is
the dangerous one. If the process dies there:

- The DB is encrypted with `newKey`
- The primary alias still has `oldKey`
- The `prev` alias also has `oldKey`

Without `prev`, the open path would try `primary` (fail) and `next`
(succeed, promote). That works — `next` still holds `newKey`.

So `prev` is not strictly necessary for that specific window. It exists
for a different case: a partial write where `primary` was updated but
the DB was not rekeyed. On the next open, `primary` fails, `next` is
gone, and `prev` (the old key) recovers the DB.

Both fallbacks are cheap. Keep them.

## Policy

The rekey check runs at app start and on resume. If the last rekey was
more than 90 days ago, `RekeyPolicy.runIfDue()` runs.

The first launch records a timestamp so the first rekey happens 90 days
after install, not 90 days after the Unix epoch.

## Cost

For a queue of a few thousand rows, SQLCipher's `PRAGMA rekey`
rewrites the entire database file. On a mid-range Android device this
is under 100 ms. On a queue of hundreds of thousands of rows it could
be seconds. The check runs at start, before the UI renders, so a slow
rekey delays the splash screen.

If the queue grows large, move the rekey to a background isolate
(not in scope for S5).

## What this does not cover

- **Rekey on device revocation.** That is a wipe, not a rekey. See
  `KeyStore.wipe()`.
- **Rekey triggered by a server signal.** If the server wants to force
  a rekey, it can return a header on the next API call. Not wired.
- **Rekey in a background isolate.** The current implementation runs on
  the main isolate.
- **Concurrent access during rekey.** The DB is locked during
  `PRAGMA rekey`; any other query waits. Since the check runs at start
  before features load, contention is not a problem.

## Tests

Two files, two levels.

**`test/core/security/rekey_policy_test.dart`** — runs on the Dart VM,
included in every `flutter test`:

- primary key is generated once and reused
- next and prev aliases are independent of primary
- isDue returns false on first call and records a timestamp
- isDue returns true after 90 days
- isDue returns false before 90 days

**`integration_test/core/storage/rekey_test.dart`** — runs on a real
device or emulator:

- rekey preserves existing rows
- rekey survives a crash after staging the next key (next alias left
  behind; open clears it)
- rekey survives a crash after the DB was rekeyed (primary fails;
  open falls back to next and promotes)

The split exists because `sqflite_sqlcipher` has no VM implementation.
It uses a method channel (`com.davidmartos96.sqflite_sqlcipher`) that
is not replaced by `sqflite_common_ffi`, so the DB-level tests must run
where the plugin has a real implementation.

Run the integration tests:

    flutter test integration_test/core/storage/rekey_test.dart -d <device-id>
