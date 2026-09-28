# S5 (mobile) Retrospective

- **Date:** 2026-09-24
- **Sprint:** S5

The backend retrospective is in
`fieldproof-backend/docs/security/s5-retrospective.md`.

---

## What went well

1. **The three-alias rekey survived its own complexity.** Three
   branches, three tests, no ambiguity about which path runs when.
2. **`RekeyPolicy.isDue` records a first-run timestamp.** Otherwise
   a fresh install would rekey on day one for no reason.
3. **The classification check took three iterations to get right.**
   Each iteration narrowed the pattern. The final version is a
   useful review aid.

## What did not go well

1. **`flutter_secure_storage` v10 broke the constructor.** The
   `encryptedSharedPreferences` flag was removed. A `flutter pub
   upgrade` pulled in v10 without warning.
2. **`sqflite_sqlcipher` has no VM implementation.** Tried the FFI
   path first. It does not work — the plugin uses its own method
   channel.
3. **Splitting the tests across `test/` and `integration_test/` was
   not obvious until the FFI attempt failed.** Should have checked
   the plugin's platform support first.

## Action items for S6

| # | Action | Applied in |
|---|--------|-----------|
| 1 | Check plugin platform support before writing tests | S6 |
| 2 | Pin `flutter_secure_storage` to a major version when behavior changes | S6 |
| 3 | Integration tests live in `integration_test/` from the start | S6 |

## Questions to carry forward

- Should the rekey run on app start or on resume? Currently both.
  Start is enough for a 90-day interval.
- Is the `prev` alias ever exercised in practice? It handles a partial
  write that may not be reachable with the current sequence. Consider
  removing it or adding a test that exercises it directly.
