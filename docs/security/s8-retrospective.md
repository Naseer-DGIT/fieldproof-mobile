# S8 Retrospective

- **Date:** 2026-10-01
- **Sprint:** S8

---

## What went well

1. **The MASVS checklist is now a living document.** Day 1 wrote it
   from intent, Day 7 updated it with evidence. It can be handed to a
   reviewer without disclaimers.
2. **MobSF and jadx found the Java layer clean.** Two real findings,
   five false positives, all triaged. The false positives are standard
   for a Flutter app and are now documented with evidence.
3. **The Dart snapshot analysis confirmed no secrets.** `strings` is a
   coarse tool, but it is enough to prove that no test credential, no
   password literal, and no PEM block survived the AOT compile.
4. **Release signing is configured and verified.** The keystore lives
   outside the repo. `key.properties` is gitignored. The Gradle config
   is guarded for CI.
5. **Attestation and root detection are design-complete.** The
   documents explain what each signal proves and what it does not.
   S11 has a clear spec.

## What did not go well

1. **The Flutter template lags AGP 9 by at least one major version.**
   The generated `build.gradle.kts` used the deprecated
   `kotlinOptions { jvmTarget = "..." }` DSL. AGP 9 turned that into a
   compilation error. The fix was a manual migration to the new
   `compilerOptions` DSL.
2. **`minSdk = flutter.minSdkVersion` resolved to 24, which MobSF
   flagged.** The override to 26 is deferred to S11.
3. **The Gradle plugin portal timed out on CI.** The Kotlin Gradle
   plugin POM failed to download. The retry succeeded, but the CI
   workflow now clears the Kotlin cache before every APK build to
   reduce the chance of a repeat.
4. **Three docs committed with `<PASTE>` markers** on Days 2 and 3.
   The check was run after the commit, not before. The fix is now in
   the commit chain (`grep -q "<PASTE" && exit 1`).
5. **The `s8-day6` tag had to be moved twice.** First because the
   signing doc was missing, then because the static analysis report
   still said the signing finding was open.
6. **`app-release.apk` is 68.5 MB.** Four ABIs are bundled. Splitting
   by ABI (`--split-per-abi`) would reduce each download to ~25 MB.
   Deferred — the target devices will download from Play, which handles
   split delivery.

## Action items for S9

| # | Action | Applied in |
|---|--------|-----------|
| 1 | Run `grep -q "<PASTE" <doc> && exit 1` before every doc commit | S9 |
| 2 | Tag only after `git status --porcelain` is empty | S9 |
| 3 | Check the Flutter template against AGP when the AGP version changes | S9 |
| 4 | Split the release APK by ABI when the download size matters | S11 |
| 5 | Move the release keystore into CI as a secret | S12 |
| 6 | Rewrite any `<PASTE>` before the commit, not after | S9 |

## Questions to carry forward

- **Play Integrity account binding.** The `accountDetails` field binds
  the verdict to a Google account. Should FieldProof require it, or is
  device integrity enough?
- **App Attest challenge lifetime.** 5 minutes is standard. Is that
  short enough for high-value events?
- **Root detection signal weight.** How much does a root flag
  contribute to the risk score? S11 decides.
- **`minSdk` bump.** Flutter 3.44 supports 21 as the minimum. Raising
  to 26 excludes Android 7.0–7.1 devices. Is that acceptable for the
  target market?
- **False positive triage.** MobSF flagged five Flutter internals. The
  pattern will repeat in S9. A small allowlist file for MobSF would
  reduce noise.
- **S9 scope.** S9 is another MobSF-focused sprint. If the Day 2–3
  analysis already covered the surface, S9 may pivot to iOS or to a
  deeper MobSF pass on the signed APK.
