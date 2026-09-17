# S1 Security Review

- **Date:** 2026-09-16
- **Sprint:** S1
- **Reviewer:** Naseer
- **Scope:** all S1 code, tests, and platform configuration
- **Related:** ADR-0001, ADR-0002, DATA_CLASSIFICATION.md §4.1/§4.2, threat_register.md

The review answers a fixed set of questions per file. A pass on the questions
is not a claim that the file is perfect; it is a claim that the S1 threat model
is met by the code as written.

---

## Summary

- Files reviewed: 10
- Findings: 1
- Blockers: 0

---

## Findings

| # | File | Severity | Finding | Action |
|---|------|----------|---------|--------|
| 1 | `lib/main.dart` | Medium | Fresh install did not create `fieldproof.db` because nothing opened it at startup (found during Day 7 attack lab). | Fixed on Day 7: `await AppDatabase.instance` added before `runApp`. |

---

## Per-file review

### lib/core/logging/secure_logger.dart

- Denylist classes present: all six (auth, secrets, biometric, location, PII, financial)
- Prod guard verified: `_SanitizedOutput.output` returns early when `Env.isProd`
- Bypass paths checked: no call sites interpolate values before calling `SecureLogger.*`
- Verdict: PASS

### lib/core/security/key_store.dart

- Key generation: `Random.secure()`, 32 bytes, base64url-encoded
- Platform storage options: Android `encryptedSharedPreferences: true`; iOS `first_unlock_this_device`
- wipe() coverage: `_storage.deleteAll()` clears every alias
- Logging of secrets: only `keystore.db_key.generated` (a boolean event) and `keystore.wiped` are logged; no key value
- Verdict: PASS

### lib/core/storage/database.dart

- Package import correct: `sqflite_sqlcipher` (not `sqflite`)
- Password passed to openDatabase: yes, from `KeyStore.getOrCreateDbKey()`
- Parameterized queries: `_onCreate` uses static strings; no dynamic concatenation
- Foreign keys enforced: `PRAGMA foreign_keys = ON` in `onConfigure`
- Verdict: PASS

### lib/core/network/api_client.dart

- Auth interceptor resilience: `try/catch` around `KeyStore.getSessionToken`; failure logs `api.auth.keystore_unavailable` and continues
- Body logging: no access to `options.data` or `response.data` in any interceptor
- DioExceptionType coverage: all cases handled including `transformTimeout`
- X-Request-ID presence: `_RequestIdInterceptor` runs before logging; header present on every request
- Verdict: PASS

### lib/main.dart

- Initialization order: `WidgetsFlutterBinding.ensureInitialized` → `Env.load` → `SecureLogger.init` → `ApiClient.init` → `AppDatabase.instance` → `runApp`
- Hardcoded secrets: none
- Verdict: PASS (with Finding 1 fixed)

### lib/app.dart and lib/features/shell/

- BlocProvider placement: above `MaterialApp`, available to every route
- Widget-side logic: no `Dio`, `ApiClient`, or repository calls in the shell presentation layer
- Widget test coverage: `test/widget_test.dart` verifies the default screen and tab switching
- Verdict: PASS

### pubspec.yaml

- Unused dependencies: none found
- Verdict: PASS

### Platform files

- Android: `allowBackup="false"` present; `minSdkVersion 23` set
- iOS: `platform :ios, '12.0'` uncommented; `ITSAppUsesNonExemptEncryption` present; `Podfile.lock` tracked
- Verdict: PASS

---

## Secrets sweep

- `git log -S "hunter2"` / `-S "fake-token"`: no commits matched
- `.env.*` ignored: `.env.dev`, `.env.staging`, `.env.prod` all ignored
- Keystore/cert files tracked: none
- `.env` files tracked: none
- Verdict: PASS

---

## Conclusion

S1 delivers the foundation promised in the sprint plan: an encrypted local
store, hardware-backed keys, sanitized logging, a resilient HTTP client, and
a BLoC shell. One medium finding from the Day 7 attack lab (DB bootstrap)
was fixed. No blockers. S1 is ready for the CI pipeline in Day 9 and the
sprint demo in Day 10.
