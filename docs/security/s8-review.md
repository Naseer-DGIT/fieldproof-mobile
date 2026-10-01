# S8 Security Review — Mobile Threat Modeling

- **Date:** 2026-10-01
- **Sprint:** S8 (Day 8)
- **Reviewer:** Naseer
- **Scope:** MASVS checklist, mobile threat model, static analysis,
  attestation, root detection, release signing, Dart snapshot
- **Related:** `docs/security/s8-masvs.md`, `docs/security/s8-mobile-threats.md`,
  `docs/security/s8-static-analysis.md`, ADR-0002

---

## Summary

- Files reviewed: 11
- Findings: 0
- Accepted limitations: 6

---

## Findings

No blocking findings. All S8 artifacts meet the sprint's scope.

---

## Accepted limitations

1. **Frida on a rooted device can read decrypted rows and hook the
   sign function.** Not preventable on the client. Server-side
   signature verification is the defense. Documented in
   `s8-mobile-threats.md` (M-011) and `s8-root-detection.md`.
2. **Attestation does not prove the user is the account holder.** A
   stolen device with the app installed passes. Documented in
   `s8-attestation.md`.
3. **Root detection is bypassable.** Magisk DenyList, Frida hooks, and
   repackaging defeat local checks. It is a risk signal, not a gate.
   Documented in `s8-root-detection.md`.
4. **`minSdk = 24` allows Android 7.0.** MobSF flagged this on Day 2.
   The bump to 26 is S11.
5. **Certificate pinning is deferred.** Documented in MASVS NETWORK-2
   and in the threat model (M-014). S11.
6. **Release keystore is on the developer machine only.** CI falls back
   to debug signing. Wiring the keystore into CI as a secret is S12.

---

## Per-file review

### docs/security/s8-masvs.md
- Every row has a status: yes
- Partial/Deferred name the closing sprint: yes
- Summary matches rows: yes
- Cross-references present: yes
- Verdict: PASS

### docs/security/s8-mobile-threats.md
- 18 threats enumerated: yes
- Every threat has a control: yes
- M-011 accepted limitation documented: yes
- M-001 and M-009 marked Partial: yes
- Verdict: PASS

### docs/security/s8-static-analysis.md
- All 7 MobSF findings triaged: yes
- False positives explained: yes
- Dart snapshot section present: yes
- Finding 1 closed: yes
- Verdict: PASS

### docs/security/s8-attestation.md
- What attestation proves documented: yes
- What it does not prove documented: yes
- Signal-not-gate decision explicit: yes
- Verdict: PASS

### docs/security/s8-root-detection.md
- Signals with false-positive notes: yes
- Bypassability documented: yes
- Signal-not-gate decision explicit: yes
- Verdict: PASS

### docs/security/s8-release-signing.md
- Keystore outside repo: yes
- Fingerprint recorded: yes
- AGP 9 Kotlin DSL note present: yes
- CI guard documented: yes
- Verdict: PASS

### android/app/build.gradle.kts
- Signing config guarded: yes
- Kotlin JVM target 17: yes
- Debug fallback for CI: yes
- Verdict: PASS

### .gitignore / android/.gitignore
- `*.jks` ignored: yes
- `*.keystore` ignored: yes
- `key.properties` ignored: yes
- No secret tracked: yes
- Verdict: PASS

### .github/workflows/ci.yml
- Kotlin cache clear present: yes
- gitleaks runs: yes
- Release APK build present: yes
- Verdict: PASS

### fieldproof-backend/docs/security/threat_register.md
- Attestation cross-reference: yes
- Root detection cross-reference: yes
- Verdict: PASS

### fieldproof-mobile/docs/security/s8-masvs-review.md
- Rows updated with S8 references: yes
- No placeholders: yes
- Verdict: PASS

---

## Sweep results

| Check | Result |
|-------|--------|
| Mobile analyze | No issues found |
| Mobile tests | all pass |
| Classification check | passed |
| No keystore or key.properties tracked | clean |
| No `.bak` files left behind | clean |
| No placeholders in S8 docs | clean |
| All S8 tags present (1–7) | yes |
| Backend cross-references | 1 each |
| Backend suite | 143 passed, 26 skipped |

---

## Threats closed or verified

| ID | Threat | S8 coverage |
|----|--------|-------------|
| M-001 | Repackaged app | Partial — signing + attestation design |
| M-002 | DB extraction | Met (S1) — confirmed by Day 3 |
| M-004 | Backup extraction | Met (S1) — confirmed by Day 3 |
| M-006 | Token in logs | Met (S1) — confirmed by Day 3 |
| M-009 | Fake device registration | Partial — attestation design |
| M-011 | Frida on rooted device | Open (accepted) |
| M-014 | TLS interception | Deferred — S11 |

---

## Conclusion

S8 delivers the mobile threat modeling phase: MASVS checklist, mobile
threat model, static analysis with jadx and MobSF, Dart snapshot
analysis, attestation evaluation, root detection design, and release
signing with a verified APK.

Six accepted limitations are documented with a sprint or a rationale.
No blocking findings. No regressions.
