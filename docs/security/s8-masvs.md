# S8 — MASVS v2.1 Checklist

- **Date:** 2026-09-30
- **Sprint:** S8 (Day 1)
- **App:** FieldProof Mobile (Flutter 3.44.2)
- **Reference:** OWASP MASVS v2.1
- **Related:** ADR-0002, `DATA_CLASSIFICATION.md`, `docs/security/s5-mobile-rekey.md`

Each control group is walked against the current S8 codebase. Status is
one of Met, Partial, Deferred, or N/A. Every non-Met entry names the
sprint that closes it.

---

## MASVS-STORAGE — Data at rest

| Req | Description | Status | Evidence / Sprint |
|-----|-------------|--------|-------------------|
| STORAGE-1 | No sensitive data stored in plaintext | **Met** | `AppDatabase` uses SQLCipher. `KeyStore` stores keys in Keychain/Keystore. S1 Day 4. |
| STORAGE-2 | Sensitive data excluded from platform backups | **Met** | `android:allowBackup="false"`. iOS: default iCloud backup excludes Keychain items with `first_unlock_this_device`. |
| STORAGE-3 | No sensitive data in logs | **Met** | `SecureLogger` denylist + prod silence. S1 Day 3. |
| STORAGE-4 | No sensitive data in the keyboard cache | **Met** | No sensitive inputs. Login uses `obscureText`. |
| STORAGE-5 | No sensitive data in screenshots / recents | **Partial** | Android `FLAG_SECURE` not set. iOS no blur. Not yet needed — no restricted data rendered. Tracked in S11. |
| STORAGE-6 | No sensitive data leakage via IPC | **Met** | Flutter uses a private channel to native code. No exported activities. |
| STORAGE-7 | No sensitive data in memory longer than needed | **Partial** | SQLCipher decrypts rows on read. Individual values live in Dart memory briefly. Documented in ADR-0002. |

---

## MASVS-CRYPTO — Cryptography

| Req | Description | Status | Evidence / Sprint |
|-----|-------------|--------|-------------------|
| CRYPTO-1 | No hardcoded cryptographic keys | **Met** | All keys generated at runtime. Verified by `scripts/check_classification.sh`. |
| CRYPTO-2 | Strong, platform-provided crypto primitives | **Met** | `cryptography` package (Ed25519), SQLCipher 4.10, Keychain/Keystore. |
| CRYPTO-3 | No custom crypto | **Met** | No custom implementations. The only crypto code is signing and key wrapping. |
| CRYPTO-4 | Secure random | **Met** | `Random.secure()`. |

---

## MASVS-AUTH — Authentication and session

| Req | Description | Status | Evidence / Sprint |
|-----|-------------|--------|-------------------|
| AUTH-1 | Authenticate on the server | **Met** | JWT with server-side verification. S3. |
| AUTH-2 | Session expiry | **Met** | 1-hour JWT TTL. `role_version` refresh (ADR-0003). |
| AUTH-3 | Server-side session invalidation | **Met** | `KeyStore.clearSession()` on 401; `role_version` bump on role change. |
| AUTH-4 | Step-up authentication for high-value actions | **Deferred** | Not needed yet. Revisit when AI actions (S20+) require approval. |
| AUTH-5 | Protect the biometric sensor from bypass | **Partial** | Liveness detection planned. Not implemented in S1–S7. S11. |

---

## MASVS-NETWORK — Network communication

| Req | Description | Status | Evidence / Sprint |
|-----|-------------|--------|-------------------|
| NETWORK-1 | TLS for all traffic | **Met** | `Env.apiBaseUrl` is HTTPS in staging/prod. Dio respects it. HSTS enforced server-side (S5 Day 1). |
| NETWORK-2 | Certificate pinning | **Deferred** | Scheduled S11. |
| NETWORK-3 | No cleartext traffic in release | **Met** | `.env.prod` uses `https://`. `AndroidManifest` does not permit cleartext. `Info.plist` has no ATS exceptions. |

---

## MASVS-PLATFORM — Platform interaction

| Req | Description | Status | Evidence / Sprint |
|-----|-------------|--------|-------------------|
| PLATFORM-1 | Minimal permissions | **Met** | Camera (for liveness), location (for check-in). No contacts, no SMS read. |
| PLATFORM-2 | IPC safe | **Met** | No exported services, receivers, or content providers. Deep links not registered. |
| PLATFORM-3 | WebViews safe | **N/A** | No WebViews in the app. |
| PLATFORM-4 | Screen overlay / tapjacking protection | **Deferred** | Not needed until biometric capture ships. S11. |
| PLATFORM-5 | App update integrity | **Deferred** | Play Store / App Store signing verification is the platform default. No in-app update path. |

---

## MASVS-CODE — Code quality and build

| Req | Description | Status | Evidence / Sprint |
|-----|-------------|--------|-------------------|
| CODE-1 | No debug code in release | **Met** | `debugShowCheckedModeBanner: !Env.isProd`. `flutter build apk --release` used in CI. |
| CODE-2 | No sensitive data in crash logs | **Met** | Crash reporting not wired. When added (S17), it must be scrubbed. |
| CODE-3 | Latest platform versions | **Met** | `minSdkVersion 23`, iOS 12.0. |
| CODE-4 | No unsafe deserialization | **Met** | JSON only via `dart:convert`. No `eval`. |

---

## MASVS-RESILIENCE — Anti-tampering

| Req | Description | Status | Evidence / Sprint |
|-----|-------------|--------|-------------------|
| RESILIENCE-1 | Root / jailbreak detection | **Deferred** | S11. Detection is a risk signal, not a block. |
| RESILIENCE-2 | Anti-debugging | **Deferred** | S11. |
| RESILIENCE-3 | Anti-tampering | **Partial** | Server-side per-event signature verification (S2). R8 in release builds. Attestation deferred to S11. |
| RESILIENCE-4 | Anti-repackaging | **Partial** | Attestation in S11. |
| RESILIENCE-5 | Anti-hooking (Frida) | **Deferred** | S10 (runtime testing). |

---

## MASVS-PRIVACY — Privacy

| Req | Description | Status | Evidence / Sprint |
|-----|-------------|--------|-------------------|
| PRIVACY-1 | Data minimization | **Met** | Server stores biometric ciphertext only; server cannot decrypt (ADR-0002). |
| PRIVACY-2 | Consent | **Deferred** | Consent screen for biometric capture is S11. |
| PRIVACY-3 | Right to deletion | **Met** | Documented in `DATA_CLASSIFICATION.md` §4.4. |
| PRIVACY-4 | No tracking without consent | **Met** | No analytics SDK installed. |

---

## Summary

| Category | Met | Partial | Deferred | N/A |
|----------|-----|---------|----------|-----|
| STORAGE | 5 | 2 | 0 | 0 |
| CRYPTO | 4 | 0 | 0 | 0 |
| AUTH | 3 | 1 | 1 | 0 |
| NETWORK | 2 | 0 | 1 | 0 |
| PLATFORM | 2 | 0 | 2 | 1 |
| CODE | 4 | 0 | 0 | 0 |
| RESILIENCE | 0 | 2 | 3 | 0 |
| PRIVACY | 3 | 0 | 1 | 0 |
| **Total** | **23** | **5** | **8** | **1** |

The partial and deferred items are the S8–S11 scope. Every deferral
names the sprint that closes it.
