# S8 — Mobile Threat Modeling: Sprint Summary

- **Sprint:** S8 (Days 1–10)
- **Branch:** `sprint/s8-mobile-security`
- **Dates:** 2026-09-30 → 2026-10-01
- **Author:** Naseer
- **Related:** ADR-0002, `docs/security/s8-masvs.md`, `docs/security/s8-mobile-threats.md`, `fieldproof-backend/docs/security/threat_register.md`

---

## Goal

Walk the mobile app through the OWASP MASVS v2.1 checklist, produce a
mobile-specific threat model, analyze the release binary, evaluate
attestation and root detection as risk signals, configure release
signing, and update the S8 documents with real evidence.

---

## Deliverables

| Day | Deliverable |
|-----|-------------|
| 1 | MASVS checklist, mobile threat model (18 threats) |
| 2 | Static analysis — jadx, apktool, MobSF triage |
| 3 | Dart snapshot analysis (`libapp.so` strings) |
| 4 | Attestation evaluation — Play Integrity, App Attest, DeviceCheck |
| 5 | Root/jailbreak detection design |
| 6 | Release signing — keystore, key.properties, signed APK |
| 7 | MASVS controls review |
| 8 | Security review |
| 9 | CI verification |
| 10 | Summary, retrospective, PR, tag |

---

## What was built

### MASVS checklist

`docs/security/s8-masvs.md` — every row has a status (Met / Partial /
Deferred / N/A) and every Partial or Deferred row names the closing
sprint.

Current totals: 23 Met, 5 Partial, 8 Deferred, 1 N/A. The partial and
deferred items are the S9–S11 scope.

### Mobile threat model

`docs/security/s8-mobile-threats.md` — 18 mobile-specific threats
(M-001 through M-018), each with a control and a verification method.

Open items:

- M-011 (Frida on rooted device) — Open, accepted limitation
- M-001 (repackaged app) — Partial, attestation design in S8, wiring in S11
- M-009 (fake device registration) — Partial, attestation design in S8, wiring in S11

### Static analysis

`docs/security/s8-static-analysis.md` — jadx, apktool, and MobSF runs
against the release APK. Seven MobSF findings triaged: two real, five
false positives.

| # | Finding | Result |
|---|---------|--------|
| 1 | Signed with debug certificate | Closed on Day 6 |
| 2 | `minSdk=24` allows Android 7.0 | S11 |
| 3 | `ProfileInstallReceiver` exported | False positive — protected by DUMP permission |
| 4 | Insecure RNG | False positive — matches in AndroidX, not in `libapp.so` |
| 5 | Hardcoded secrets | False positive — byte tables from Bouncy Castle |
| 6 | App logs information | False positive — Flutter engine logs |
| 7 | Copies data to clipboard | False positive — Flutter engine capability |

### Dart snapshot

`strings -n 6` on `libapp.so` (5.4 MB) produced 14,440 lines. No
secret literals, no test credentials, no debug paths. Positive checks
confirmed the logger event names and payload field names are present,
which proves the analysis targeted the correct binary.

### Attestation

`docs/security/s8-attestation.md` — what Play Integrity, App Attest,
and DeviceCheck each prove and do not prove. Decision: attestation is
a risk signal, not a gate. Wiring is S11.

### Root detection

`docs/security/s8-root-detection.md` — signals, false-positive rates,
and why local detection is bypassable (Magisk DenyList, Frida,
repackaging). Decision: root is a risk input, not a block. Wiring is
S11.

### Release signing

`docs/security/s8-release-signing.md` — dedicated 4096-bit RSA keystore,
`android/key.properties` gitignored, Gradle signing config guarded for
CI.

Certificate fingerprint:
