# S8 — Root and Jailbreak Detection

- **Date:** 2026-10-01
- **Sprint:** S8 (Day 5)
- **Author:** Naseer
- **Related:** `docs/security/s8-mobile-threats.md` (M-011), `docs/security/s8-attestation.md`, ADR-0002

A design document, not an implementation. The wiring is S11.

---

## Why this document exists

A common misconception: "If the phone is rooted, block the app." That
policy causes more problems than it solves. It locks out legitimate
users, produces false positives on unusual but clean devices, and
rarely stops a determined attacker.

Root detection is useful when it is treated as a **risk signal** that
feeds a server-side score, not a client-side gate.

This document explains what detection actually detects, why it is
bypassable, and how FieldProof uses it.

---

## What root/jailbreak detection detects

Signals, from weakest to strongest:

| Signal | What it observes | False positive rate |
|--------|------------------|---------------------|
| Presence of `su`, `magisk`, `superuser` binaries | Filesystem artifacts | Low |
| Writable `/system` or `/system/xbin` | Filesystem permissions | Low |
| `build.tags` includes `test-keys` (Android) | OS build metadata | Low |
| Known root-management apps installed | Package list | Medium — some apps are used by legitimate developers |
| `/proc/mounts` includes `rw` on system paths | Mount flags | Low |
| SafetyNet / Play Integrity hardware-backed attestation | A server-side verdict | Very low (it is Google's signal) |
| Cydia / Sileo presence (iOS) | Package managers | Low |
| Writable `/private` (iOS) | Filesystem permissions | Low |
| `fork()` succeeds (iOS, historically) | Process model | Bypassed on modern iOS |
| Symbolic links to `/Applications` outside the sandbox (iOS) | Filesystem | Low |

**The strongest Android signal is Play Integrity.** It is server-side,
hardware-backed on modern devices, and the verdict is signed by Google.
Local detection adds little beyond it.

---

## Why root detection is bypassable

Local detection runs inside the app's own process. The attacker who can
root the device can also:

- **Hide the artifacts.** Magisk (a common root manager) ships with a
  "DenyList" feature. When the app's package name is added to the list,
  the root artifacts are invisible to it.
- **Hook the detection function.** Frida can replace the return value
  of any Java/Kotlin method or native function that checks for root.
- **Patch the app.** Repackaging tools modify the APK to remove the
  check. If attestation is not enforced server-side, the patched app
  runs normally.
- **Run the check in a shadow environment.** Some tools emulate a clean
  device, presenting the app with a fake filesystem view.

Any local check is a speed bump, not a wall. This is not a Flutter
limitation; it is a property of the client.

---

## How FieldProof uses it

### Design principle

**Root is a risk input, not a gate.** The server records the signal,
scores it against other signals, and decides whether to require extra
review. The client never blocks the user.

### Registration (S2 flow)

1. The app collects root signals (from the `flutter_jailbreak_detection`
   or similar package).
2. It sends the signal along with the attestation verdict to the backend.
3. The backend stores the root flag on the device row as part of the
   risk profile.
4. Registration proceeds regardless of the signal.

### On high-value events

- A root signal increases the risk score for the event.
- Above a threshold, the event is added to the review queue (S7 Day 6).
- Repeated high-risk events on the same device trigger a supervisor
  override requirement for the next check-in.

### On the security dashboard

- Devices with a root signal are listed.
- The signal is displayed alongside attestation status, mock-location
  flags, and clock anomalies.
- A reviewer can see the full risk profile before deciding.

### Why not block

- **Legitimate rooted devices exist.** Some field workers use rooted
  phones for longer battery life, custom ROMs, or accessibility needs.
- **False positives lock out real users.** A false positive on a
  genuine device is worse than accepting a forged one. The cost of a
  locked-out worker on a construction site is high.
- **The real defense is server-side.** Per-event Ed25519 signature
  verification rejects forged attendance even if the device is rooted.
  Root detection adds context, not protection.

---

## Threat model impact

| Threat | Before | After wiring (S11) |
|--------|--------|---------------------|
| M-011 Frida on rooted device | Open (accepted) | Open — detection is a signal, not a block |
| M-009 fake device registration | Partial | Partial — root adds a signal |
| M-012 mock location | Partial | Partial — root correlates with mock location |

Root detection does not close M-011. It cannot. The Frida attacker owns
the process. The mitigation is server-side signature verification, which
is already in place (S2 Day 5).

---

## What this does not decide

- **Which detection library.** `flutter_jailbreak_detection` is common,
  but alternatives exist. S11 picks.
- **The risk-score weight.** S11.
- **The threshold for review.** S11.
- **The response time for a flagged device.** S11.

The S8 goal is to name the signal and its limits.

---

## Summary

| Question | Answer |
|----------|--------|
| Does root detection stop an attacker? | No. It is bypassable. |
| Does it add value? | Yes, as a risk signal correlated with other signals. |
| Should it block the user? | No. Review, not block. |
| What is the strongest signal? | Play Integrity (Android) / App Attest (iOS). |
| What is the real defense? | Server-side signature verification and audit trail. |
