# S8 — Attestation Signal Evaluation

- **Date:** 2026-10-01
- **Sprint:** S8 (Day 4)
- **Author:** Naseer
- **Related:** `docs/security/s8-mobile-threats.md`, ADR-0002, `fieldproof-backend/docs/security/threat_register.md`

A design document, not an implementation. The wiring is S11.

---

## Why attestation

Two threat-model entries cannot be closed by client-side controls alone:

| ID | Threat | Why the client cannot close it |
|----|--------|-------------------------------|
| M-001 | App repackaged with a modified sign function | The attacker controls the binary; any local check is bypassable |
| M-009 | Attacker registers their device as the victim | The device is not the victim's real hardware |

Both need a signal that the *server* can verify. That signal is attestation.

---

## What each platform provides

### Android — Play Integrity API

Google's server-side service. The app requests a signed integrity verdict
from Google Play, sends it to the FieldProof backend, and the backend
verifies the signature against Google's public keys.

The verdict carries:

| Field | Meaning |
|-------|---------|
| `MEETS_DEVICE_INTEGRITY` | The device passed Android compatibility and is not rooted in a way Play detects |
| `MEETS_BASIC_INTEGRITY` | The app is unmodified and installed by Play |
| `MEETS_STRONG_INTEGRITY` | The device is not rooted, not bootloader-unlocked, and the app is running on genuine hardware |
| `PLAY_RECOGNIZED` | The app is recognized by Play (installed from Play or a preload) |
| `LICENSED` | The user installed the app from Play |
| `appIntegrity` | The package name and signing certificate digest |
| `accountDetails` | If the user is signed into Play, an obfuscated account id |

### iOS — App Attest

Apple's device attestation. The app generates a key in the Secure
Enclave, asks Apple to certify the key, and sends the assertion to the
FieldProof backend. The backend verifies against Apple's root
certificate.

The assertion carries:

| Field | Meaning |
|-------|---------|
| Attestation object | A certificate proving the key was generated in a genuine Apple device's Secure Enclave |
| Assertion | A signature over a server-provided challenge, proving the key is being used on the same device |
| `receipt` | A signed receipt from the App Store proving the app was installed from the App Store |

### iOS — DeviceCheck

A lighter-weight signal. Two bits of per-device state that persist across
app installs. Used to mark a device as "seen" or "revoked."

| Field | Meaning |
|-------|---------|
| Two bits | Free-form, server-defined |
| Not a signature | DeviceCheck does not prove the device is genuine |
| Not suitable alone | Use alongside App Attest, not instead |

---

## What attestation proves

- **The app binary matches the declared signing certificate.** A repackaged APK with a different signature fails attestation.
- **The device is running a Play/App Store-provided build.** Sideloaded builds fail.
- **The device is not obviously compromised.** Rooted Android phones fail `MEETS_STRONG_INTEGRITY`. Jailbroken iPhones fail App Attest.

---

## What attestation does not prove

- **That the user is the legitimate account holder.** A stolen device with the app installed passes attestation.
- **That the app has not been hooked at runtime.** Frida on a rooted device is not detected by attestation; the verdict was issued at request time, not continuously.
- **That the location is real.** Attestation says nothing about GPS.
- **That the biometric is real.** Attestation says nothing about liveness.
- **That the device is not shared.** Two employees using the same phone both pass.

Attestation is a **device-and-binary signal**, not a user signal.

---

## How FieldProof will use it

Per the FieldProof threat model:

### At device registration (S2 flow)

1. The app requests a verdict from Play Integrity or App Attest.
2. It sends the verdict along with the public key.
3. The backend verifies the signature against Google's / Apple's keys.
4. The result is stored on the device row as `attestation_status`:
   - `VERIFIED` — verdict passes all required checks
   - `PENDING` — Google/Apple was unreachable; retry later
   - `FAILED` — verdict was rejected
5. The device is bound regardless. Registration is not blocked.
6. `FAILED` devices are flagged for the security dashboard (S7 Day 6).

### On high-value events

The S2 plan says attestation is checked periodically. Design:

- **On first check-in of the day**, request a fresh verdict.
- **Every N events** (N = 50), request a fresh verdict.
- **On any event flagged as risky** (mock-location, GPS anomaly), request a fresh verdict.

Each verdict is stored in the `authorization_events` table (S3 Day 6) as
a security signal, not a block.

### Why not block on FAILED

- A legitimate user on a rooted device (some field workers use rooted
  phones for legitimate reasons — longer battery, custom ROMs) would be
  locked out.
- Google's verdicts are not perfectly reliable. A false negative on a
  genuine device is worse than accepting a forged one.
- Server-side signature verification of attendance events is the real
  defense. Attestation is a risk multiplier, not a gate.

The response to a low attestation score is:

1. Log the event with a risk flag.
2. Increase the review queue priority.
3. On repeated failures, require a supervisor override for check-in.

Not: "you cannot check in."

---

## Threat model impact

| Threat | Before S8 Day 4 | After wiring (S11) |
|--------|-----------------|---------------------|
| M-001 repackaged app | Open | Partial — attestation signal, no block |
| M-009 fake device registration | Partial | Partial — attestation on registration |
| M-011 Frida on rooted device | Open (accepted) | Open (accepted) — attestation does not detect Frida |
| M-012 mock location | Partial | Partial — attestation adds a signal |

Attestation moves M-001 and M-009 from "open" to "partial." Full closure
is not possible on a user-controlled device.

---

## Implementation notes for S11

Not today, but the design decisions the S11 work will need:

### Play Integrity

- Requires a Google Cloud project with the Play Integrity API enabled.
- Requires the app to be published to Play (internal testing track is sufficient).
- The server must cache Google's public keys and rotate them.
- The verdict is an opaque blob up to ~4 KB; store it or its hash, not the full blob, in the device row.

### App Attest

- Requires an Apple Developer account.
- The attestation and assertions are CBOR-encoded; the server needs a CBOR parser.
- The challenge is generated by the server, valid for one use, and expires in 5 minutes.
- The public key is per-install, not per-device. Reinstall means a new key.

### Both

- The server needs a small library or a direct HTTP call to the platform's verification endpoint.
- The verdicts are cacheable for a short window (Play: minutes, App Attest: the challenge lifetime).
- A verdict older than X is not accepted for a high-value action.

---

## What this document does not decide

- **Which verdict fields are required.** S11 makes that call once the Play and Apple developer accounts exist.
- **Retry policy for `PENDING`.** S11.
- **Whether the verdict is required for every user or only those flagged by other signals.** S11.
- **The exact N for the "every N events" rule.** S11.
- **The response when the platform API is down.** S11.

The S8 goal is to name the signal and its limits. S11 implements.

---

## Summary

| Question | Answer |
|----------|--------|
| Does attestation block attackers? | No. It raises cost and adds signal. |
| Does it close M-001 / M-009 fully? | No. Partial. |
| Can a stolen device pass attestation? | Yes. The user is not attested. |
| Can Frida bypass it? | Yes, on a rooted device. |
| Is it still worth implementing? | Yes. It is the industry standard for app-and-device trust. |
