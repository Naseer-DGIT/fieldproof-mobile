# S8 Day 7 — MASVS Controls Review

- **Date:** 2026-10-01
- **Sprint:** S8 (Day 7)
- **Related:** `s8-masvs.md`, `s8-attestation.md`, `s8-root-detection.md`, `s8-release-signing.md`

A short review of the MASVS v2.1 checklist after Days 2–6 moved several
rows. The goal is to keep the checklist current so it can be handed to
a reviewer without disclaimers.

---

## What moved

| Req | Before | After | Why |
|-----|--------|-------|-----|
| STORAGE-1 | Met | Met (with evidence) | Day 3 confirmed no plaintext secrets in `libapp.so` |
| STORAGE-3 | Met | Met (with evidence) | Day 3 confirmed logger names present, no values |
| CRYPTO-1 | Met | Met (with evidence) | Day 3 confirmed no hardcoded keys |
| RESILIENCE-3 | Partial | Partial (with reference) | Release APK now signed with a dedicated keystore (Day 6) |
| RESILIENCE-4 | Partial | Partial (with reference) | Signed APK raises the repackaging bar; attestation in S11 |
| RESILIENCE-1 | Deferred | Deferred (with design) | `s8-root-detection.md` exists; wiring in S11 |

No row moved more than one level. Nothing closed fully that was open
on Day 1.

---

## What is still open

| Category | Count | Notes |
|----------|-------|-------|
| Deferred | 8 | Mostly S11 (attestation, root detection, pinning, anti-debug) and S12 (obfuscation, supply chain) |
| Partial | 5 | Tampering, anti-repackaging, biometric liveness |

Every open row names the sprint that closes it.

---

## What this review confirms

- The MASVS checklist is not a static document. It is updated as code
  changes.
- The three S8 documents (attestation, root detection, release signing)
  are now referenced from the checklist.
- No regressions were introduced by the S8 changes.

---

## What this review does not cover

- **Formal MASVS certification.** Not in scope.
- **iOS controls.** Only Android was built and signed in S8. iOS
  attestation (App Attest) is designed but not implemented.
- **Penetration testing.** S6 covered the backend; the mobile runtime
  tests are S10.
