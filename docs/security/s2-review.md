# S2 Security Review — Attendance Feature

- **Date:** 2026-09-17
- **Sprint:** S2 (Day 8)
- **Reviewer:** Naseer
- **Scope:** all files added in S2 Days 4–7 (mobile), Days 4–5 (backend)
- **Related:** ADR-0001, ADR-0002, DATA_CLASSIFICATION.md §4.1/§4.2, threat_register.md

The review answers a fixed set of questions per file. A pass is not a
claim that the file is perfect; it is a claim that the S2 threat model
is met by the code as written.

---

## Summary

- Files reviewed: 10
- Findings: 0
- Accepted limitations: 3

---

## Findings

No findings. All verification paths exercised end-to-end by
`fieldproof-backend/scripts/test_attendance_events.py` (ALL PASS).

---

## Accepted limitations

1. **Private key in process memory during signing.** `DeviceKey.sign`
   reads the seed from KeyStore, constructs a key pair, signs, and
   discards. The seed is in process memory for microseconds. Unavoidable
   with the current crypto library. Documented in ADR-0002 §Security
   implications. Fixable only with a hardware signing API (Android
   StrongBox / iOS Secure Enclave) — S11 candidate.

2. **Chain is scoped to device, not user.** A revoked and re-registered
   device starts a new chain. The server enforces
   `AttendanceEvent.device_id == device.id`. If the product later needs
   a user-scoped chain, revocation must be handled explicitly. Out of
   scope for S2.

3. **Retry count has no cap.** The BLoC backs off to 10 minutes but
   never gives up. A permanently retryable event will loop indefinitely.
   A `max_attempts` field with a `dead_letter` status is S5+ work.

---

## Per-file review

### lib/features/attendance/domain/attendance_event.dart

- Timestamp is UTC: yes (`DateTime.now().toUtc()`)
- Canonical JSON deterministic (sorted keys, no whitespace): yes
- Payload includes event_id and type for server cross-check: yes
- previous_hash omitted when null: yes
- Verdict: PASS

### lib/features/attendance/data/attendance_queue.dart

- Single storage path through AppDatabase (SQLCipher): yes
- SyncStatus enum explicit (four values): yes
- `clearAll` reachable from production code: no
- `retry_count` update uses parameterized SQL: yes
- Verdict: PASS

### lib/features/attendance/data/attendance_repository.dart

- Signing owned by repository: yes
- Idempotency key generated per event: yes
- Throws clearly if device key missing: yes (`StateError`)
- Verdict: PASS

### lib/features/attendance/data/sync_worker.dart

- Stops on first retryable failure: yes
- Stops on first conflict: yes
- Rejected rows marked and skipped: yes
- Logs contain no payload or signature: yes
- Verdict: PASS

### lib/core/security/device_key.dart

- Private key stored in KeyStore: yes
- Private key never logged: yes
- Key reused across calls (not regenerated): yes
- No export path: yes
- Verdict: PASS (with accepted limitation 1)

### lib/features/attendance/presentation/bloc/attendance_bloc.dart

- Retry timer cancelled on close: yes
- Concurrent sync prevented: yes (timer cancelled before emit)
- No sensitive fields in logs: yes
- Verdict: PASS

### lib/core/lifecycle/sync_on_resume.dart

- Observer removed on dispose: yes
- Safe when AttendanceBloc is absent: yes (`try/catch`)
- Fires only on `resumed`: yes
- Verdict: PASS

### fieldproof-backend/app/api/attendance.py

- Device resolved before signature check: yes
- Signature verified over the raw signed bytes: yes
- Body fields cross-checked against payload: yes
- Chain scope: device
- Chain compares `event_id`, not `id`: yes
- Error responses contain no internals: yes
- Verdict: PASS (with accepted limitation 2)

### fieldproof-backend/app/services/signatures.py

- Handles padded and unpadded base64: yes
- Returns False on InvalidSignature and ValueError: yes
- Verdict: PASS

### fieldproof-backend/app/api/devices.py

- Idempotent for same public key: yes
- Previous devices revoked, not deleted: yes
- One active device per user: yes
- `platform` validated by Pydantic pattern: yes
- Verdict: PASS

---

## Secrets sweep

| Command | Result |
|---------|--------|
| `grep SecureLogger` for payload/signature/seed | clean |
| `grep PRIVATE KEY` in lib/ | clean |
| `grep clearAll` outside queue file | clean |
| `.env.*` tracked in git | clean |
| `Test1234` in tracked backend files | clean |

---

## Conclusion

S2 delivers signed, queued, idempotent, chain-verified attendance
events. All verification paths are exercised end-to-end by
`scripts/test_attendance_events.py` (ALL PASS). Three accepted
limitations are documented. No blocking findings.
