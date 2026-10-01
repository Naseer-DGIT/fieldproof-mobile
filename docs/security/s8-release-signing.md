# S8 — Release Signing Setup

- **Date:** 2026-10-01
- **Sprint:** S8 (Day 6)
- **Related:** `docs/security/s8-static-analysis.md`, `docs/security/s8-masvs.md`, ADR-0002

---

## What

Release builds are signed with a dedicated keystore, not the debug
keystore. The keystore lives outside the repo. The passwords live in
`android/key.properties`, which is gitignored.

This closes finding 1 from the S8 static analysis report
("Application signed with debug certificate").

---

## Keystore generation (once)

The keystore file and both passwords must be backed up to two
locations outside the repo (password manager, encrypted cloud storage,
or a physical safe). Losing the keystore forces a new app identity on
Google Play.

---

## Release certificate fingerprint

The release certificate generated on 2026-10-01:

This is the app identity. It matches what Google Play shows after
upload. If it changes, the keystore was replaced and Play will reject
subsequent uploads. Back up the keystore and both passwords.

---

## Configuration

`android/key.properties` (gitignored):

`android/app/build.gradle.kts` reads the file and applies it to the
`release` build type. The `signingConfigs` block is guarded with
`if (hasReleaseKeystore)` so CI (which does not have the file) still
compiles.

---

## Build

---

## Verify

---

## AGP 9 note

The Flutter 3.44 template emits the deprecated Kotlin DSL
(`kotlinOptions { jvmTarget = "..." }`). AGP 9.0 treats it as a
compilation error. The fix is the new top-level `compilerOptions` DSL:

```kotlin
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_17)
    }
}
