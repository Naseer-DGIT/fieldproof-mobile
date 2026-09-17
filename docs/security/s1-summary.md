# S1 — Secure Flutter Foundation: Sprint Summary

- **Sprint:** S1 (Days 1–10)
- **Branch:** `sprint/s1-flutter-foundation`
- **Dates:** 2026-09-09 → 2026-09-17
- **Author:** Naseer
- **Related:** ADR-0001, ADR-0002, DATA_CLASSIFICATION.md, threat_register.md

---

## Goal

Build a Flutter app skeleton that is secure by default — encrypted local
storage, hardware-backed keys, sanitized logging, a resilient HTTP client,
and an explicit BLoC state pattern. No business features yet. The
foundation that S2–S24 plug into.

---

## Deliverables

| Day | Deliverable | Commit |
|-----|-------------|--------|
| 1 | Flutter project + security-first folder structure | `08520ac` |
| 2 | Environment config with fail-fast flavor loader | `f2fea6f` |
| 3 | Secure logger with denylist redaction + prod silence | `3a70083` |
| 4 | KeyStore + SQLCipher DB + storage lab report | `4fa142a` |
| 5 | Secure Dio client + iOS deployment target 12.0 | `262c0b0` |
| 6 | BLoC app shell with 4 tabs + tests | `ea5b2c0` |
| 7 | DB bootstrap fix + attack lab report | `4ef9765` |
| 8 | Testing sweep + security review | `a7ee501` |
| 9 | CI pipeline + branch protection + Flutter pin | `d9d486e` |
| 10 | Summary, retrospective, PR, tag | *(this PR)* |

---

## What was built

### Storage

- Random 256-bit DB key generated on first launch (`Random.secure()`)
- Stored in `flutter_secure_storage` with `EncryptedSharedPreferences` (Android)
  and `first_unlock_this_device` (iOS)
- SQLCipher-encrypted SQLite DB opened at startup from `lib/main.dart`
- `android:allowBackup="false"` prevents `adb backup` extraction
- `minSdkVersion 23`, iOS deployment target 12.0

### Logging

- Denylist covers all six data classes from `DATA_CLASSIFICATION.md` §4.1
- Recursive redaction of nested maps
- Allowlist path (`SecureLogger.event`) for structured events
- Prod guard: writes nothing to console when `Env.isProd`
- Values truncated at 500 characters

### Networking

- Dio client configured from `Env` at startup
- Four interceptors in order: auth → request ID → logging → error
- Auth interceptor survives a KeyStore failure (does not abort the request)
- Error interceptor maps every `DioExceptionType` to a sealed `ApiFailure`
- No request or response bodies ever logged

### UI

- BLoC pattern per ADR-0001 — events, states, testable transitions
- Four-tab shell using `NavigationBar` + `IndexedStack`
- `BlocProvider` above `MaterialApp`
- Widget tests verify tab switching
- BLoC unit tests verify all transition paths

### CI

- Analyze, test, gitleaks, release APK build on every push
- Flutter pinned to 3.44.2 (matches local Dart 3.12.2)
- Branch protection on `main` requires PR + green checks
- Direct push to `main` blocked (`GH006`)

---

## Verification

- `flutter analyze` → `No issues found!`
- `flutter test` → `+13: All tests passed!`
- 8 attack labs documented in `s1-day7-attack-lab.md`, all PASS
- Storage review in `s1-review.md`, no open findings
- CI green on `sprint/s1-flutter-foundation` (run `35185562781`)

---

## Findings resolved during the sprint

| # | Finding | Severity | Resolution |
|---|---------|----------|-----------|
| F-1 | DB file not created on fresh install because nothing opened it at startup | Medium | `lib/main.dart` now awaits `AppDatabase.instance` |
| — | iOS `pod install` failed due to deployment target 11.0 | Low | `platform :ios, '12.0'` in `Podfile` + `post_install` override |
| — | `psycopg2` had no wheels for Python 3.14 | Low | Backend switched to `psycopg[binary]` (psycopg3) |
| — | `AppShellState` named parameter incompatible with `super.selectedIndex` | Low | Parent constructor changed to positional |
| — | CI pinned Flutter 3.24.0 but pubspec requires Dart 3.12.2 | Medium | CI pinned to Flutter 3.44.2 |

---

## Explicitly out of scope (moved to later sprints)

- Auth flow, device registration, check-in/out — S2
- Backend RBAC and tenant isolation enforcement — S3
- OWASP AppSec lab — S4
- TLS, KMS, backup/DR — S5
- API pentest — S6
- Analytics and reports — S7
- Mobile MASVS/MASTG — S8
- MobSF static analysis — S9
- Frida runtime testing — S10
- Certificate pinning — S11

---

## Metrics

- Commits on the sprint branch: 15
- Test files: 4
- Tests: 13
- Files under `lib/core/`: 6
- Files under `lib/features/shell/`: 6
- ADRs referenced: 2
- Threat register entries closed or mitigated: T-011 (local DB tampering)
