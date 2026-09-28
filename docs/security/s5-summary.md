# S5 (mobile) — Crypto & Data: Sprint Summary

- **Sprint:** S5 (Days 6–7 mobile scope)
- **Branch:** `sprint/s5-crypto`
- **Dates:** 2026-09-24
- **Author:** Naseer
- **Related:** ADR-0002, ADR-0004, DATA_CLASSIFICATION.md

The backend scope of S5 is covered in
`fieldproof-backend/docs/security/s5-summary.md`.

---

## Goal

Mobile work in S5 covers two areas: rotating the SQLCipher database key
without losing the queue, and enforcing the data classification rules
at build time.

---

## Deliverables

| Day | Deliverable | Commit |
|-----|-------------|--------|
| 6 | SQLCipher rekey — crash-safe two-phase rotation | `2d2b41d` |
| 7 | Classification check in CI | `59d93f1` |
| 9 | (no mobile change) CI verification | `c863616` |

---

## What was built

### Rekey

- Three-alias scheme in `KeyStore`: `fp_db_key_v1`, `fp_db_key_next_v1`,
  `fp_db_key_prev_v1`
- `AppDatabase._open` tries each in order:
  1. primary
  2. next (rekey completed but promotion did not)
  3. prev (promotion happened but rekey did not)
- `AppDatabase.rekey()` runs five phases
- `RekeyPolicy.isDue()` enforces the 90-day interval
- `RekeyPolicy.runIfDue()` called from `main.dart` after DB open

The open path recovers from a crash at any point in the rekey. The
tests cover three crash scenarios.

### Classification

- `scripts/check_classification.sh`
- Runs in CI after `flutter analyze`
- Fails on:
  - `print` / `debugPrint` in `lib/` outside `secure_logger.dart`
  - Forbidden identifiers interpolated into a log call
  - Forbidden identifiers used as map keys in a log call
  - `shared_preferences` imports in `lib/`
- Allow marker: `// check-classification: allow`

The check distinguishes event names (`'keystore.db_key.generated'`) from
data (`'db_key': value`). A message string is not a violation.

---

## Verification

- `flutter analyze` → No issues found
- `flutter test` → all pass
- `./scripts/check_classification.sh` → passed
- Integration test `integration_test/core/storage/rekey_test.dart`
  requires a device; runs `PRAGMA rekey` against real SQLCipher

---

## Findings resolved during the sprint

| # | Finding | Resolution |
|---|---------|-----------|
| F-1 | `flutter_secure_storage` v10 removed `encryptedSharedPreferences` | Dropped the parameter; v10 uses RSA OAEP + AES-GCM by default |
| F-2 | `sqflite_sqlcipher` has no VM implementation | Split tests: policy on the VM, DB on a device |
| F-3 | Classification check flagged the logger's own `print` | Path allowlist |

---

## Accepted limitations

1. **Rekey runs on the main isolate.** A large queue could delay the
   splash screen. Background-isolate rekey is S14 work.
2. **Classification check is a static grep.** A value passed through a
   renamed local is not caught.

---

## Metrics

- Commits on the sprint branch: 3 (mobile)
- Mobile tests: all passing
- Integration tests: 3 (device-only)
- ADRs referenced: 1 (ADR-0002)
