# S8 — Mobile Threat Model

- **Date:** 2026-09-30
- **Sprint:** S8 (Day 1)
- **App:** FieldProof Mobile
- **Related:** `fieldproof-backend/docs/security/threat_register.md`, ADR-0002

Mobile-specific threats, following the S0 STRIDE pattern. Each names
the asset, the attacker's goal, the control, and the test or sprint
that verifies it.

---

## Threat register — mobile

| ID | Asset | STRIDE | Threat | Control | Verification | Status |
|----|-------|--------|--------|---------|--------------|--------|
| M-001 | App binary | Tampering | App repackaged with a modified sign function | Play Integrity / App Attest at registration and on high-value events | S11 — see `s8-attestation.md` | Partial |
| M-002 | Local DB | Info disclosure | DB file extracted from a rooted device | SQLCipher AES-256 | S1 attack lab (`sqlite3` → "file is not a database") | Met |
| M-003 | Signing key | Spoofing | Frida hooks `DeviceKey.sign` | Server-side signature verification against registered public key | S2 Day 5 end-to-end test | Met (client hook still possible; server rejects) |
| M-004 | Local data | Info disclosure | Android backup extracts Keychain / EncryptedSharedPreferences | `allowBackup="false"` | S1 attack lab (adb backup produced no `databases/`) | Met |
| M-005 | Release build | Spoofing | Debug APK shipped to users | CI builds `--release` only | `.github/workflows/ci.yml` release step | Met |
| M-006 | Session token | Info disclosure | Token read from device logs | `SecureLogger` denylist + prod silence | `scripts/check_classification.sh` | Met |
| M-007 | Biometric | Info disclosure | Biometric embedding extracted from device storage | Embedding is encrypted on-device before sync; server stores ciphertext | ADR-0002 | Partial — capture not yet implemented |
| M-008 | Local DB | Tampering | Attacker edits the SQLCipher DB on a rooted device | Per-event Ed25519 signature + server verification | S2 Day 5 test 4 (signature tampering → 400) | Met |
| M-009 | Device binding | Spoofing | Attacker registers their device as the victim | Device registration requires an authenticated token; attestation adds signal | S2 Day 3 + S11 — see `s8-attestation.md` | Partial |
| M-010 | Rekey operation | Denial of service | Attacker interrupts `PRAGMA rekey` at a specific point | Three-alias crash-safe rekey with fallback open | S5 Day 6 rekey tests (3 scenarios) | Met |
| M-011 | Rooted device | Info disclosure | Frida reads decrypted rows from a running app | Not preventable. Server-side controls are the answer | S10 runtime report | Open — accepted limitation |
| M-012 | Mock location | Spoofing | Attacker sets a fake GPS position | Mock-location detection is a risk signal, not a block | Documented in `Product_Project_Document.md` §9 | Partial |
| M-013 | Device clock | Tampering | Attacker rolls the device clock back | Server timestamps on receive; monotonic elapsed time | S2 Day 5 chain check | Met |
| M-014 | TLS | Info disclosure | Attacker intercepts traffic with a rogue CA | Certificate pinning | S11 | Deferred |
| M-015 | Deep links | Spoofing | Attacker crafts a URL that opens the app to a hostile state | No deep links registered yet | N/A until a feature adds them | N/A |
| M-016 | Crash reporter | Info disclosure | Crash dumps contain payloads, tokens, or location | No crash reporter installed | When one is added (S17), it must be scrubbed | Deferred |
| M-017 | Rekey timestamp | Tampering | Attacker sets `last_rekey_at` to the future so rekey never runs | Timestamp lives in `flutter_secure_storage`; not user-writable without root | S5 Day 6 | Met |
| M-018 | AI prompt | Info disclosure | Mobile sends PII into an AI prompt | Not implemented yet. AI proxy is backend-only | S20 | N/A |

---

## Summary

| Status | Count |
|--------|-------|
| Met | 9 |
| Partial | 6 |
| Deferred | 2 |
| Open (accepted) | 1 |
| N/A | 2 |

The change from the previous count: M-001 and M-009 move from
Deferred to Partial after the attestation evaluation on Day 4. See
`s8-attestation.md`.

### Accepted limitations

**M-011** — Frida on a rooted device can read decrypted rows and hook
signing. No client-side control prevents this. The server rejects
forged signatures because the private key never leaves the device.
Detection is a risk signal, and the response is a review-queue event,
not a block. Documented in ADR-0002.

### What this threat model does not cover

- **Supply chain** of the Flutter toolchain and pub.dev packages.
  S12–S14.
- **Cloud infrastructure** attacks. S15.
- **AI-specific attacks** (prompt injection, RAG poisoning). S20–S23.

---

## How to use this

1. Every S8 sprint doc references the threat ID it addresses.
2. The mobile review at Day 8 walks each row and updates Status.
3. When a new feature adds a mobile attack surface, add a row before
   the code lands.
