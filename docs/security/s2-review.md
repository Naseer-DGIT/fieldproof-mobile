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
- Findings: ___
- Accepted limitations: 3

---

## Findings

| # | File | Severity | Finding | Action |
|---|------|----------|---------|--------|
| 1 | ___ | ___ | ___ | ___ |

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

- Timestamp is UTC: ___
- Canonical JSON deterministic (sorted keys, no whitespace): ___
- Payload includes event_id and type for server cross-check: ___
- previous_hash omitted when null: ___
- Verdict: ___

### lib/features/attendance/data/attendance_queue.dart

- Single storage path through AppDatabase (SQLCipher): ___
- SyncStatus enum explicit (four values): ___
- `clearAll` reachable from production code: ___
- `retry_count` update uses parameterized SQL: ___
- Verdict: ___

### lib/features/attendance/data/attendance_repository.dart

- Signing owned by repository: ___
- Idempotency key generated per event: ___
- Throws clearly if device key missing: ___
- Verdict: ___

### lib/features/attendance/data/sync_worker.dart

- Stops on first retryable failure: ___
- Stops on first conflict: ___
- Rejected rows marked and skipped: ___
- Logs contain no payload or signature: ___
- Verdict: ___

### lib/core/security/device_key.dart

- Private key stored in KeyStore: ___
- Private key never logged: ___
- Key reused across calls (not regenerated): ___
- No export path: ___
- Verdict: ___ (with accepted limitation 1)

### lib/features/attendance/presentation/bloc/attendance_bloc.dart

- Retry timer cancelled on close: ___
- Concurrent sync prevented: ___
- No sensitive fields in logs: ___
- Verdict: ___

### lib/core/lifecycle/sync_on_resume.dart

- Observer removed on dispose: ___
- Safe when AttendanceBloc is absent: ___
- Fires only on `resumed`: ___
- Verdict: ___

### fieldproof-backend/app/api/attendance.py

- Device resolved before signature check: ___
- Signature verified over the raw signed bytes: ___
- Body fields cross-checked against payload: ___
- Chain scope: ___
- Chain compares `event_id`, not `id`: ___
- Error responses contain no internals: ___
- Verdict: ___ (with accepted limitation 2)

### fieldproof-backend/app/services/signatures.py

- Handles padded and unpadded base64: ___
- Returns False on InvalidSignature and ValueError: ___
- Verdict: ___

### fieldproof-backend/app/api/devices.py

- Idempotent for same public key: ___
- Previous devices revoked, not deleted: ___
- One active device per user: ___
- `platform` validated by Pydantic pattern: ___
- Verdict: ___

---

## Secrets sweep

| Command | Result |
|---------|--------|
| `grep SecureLogger` for payload/signature/seed | ___ |
| `grep PRIVATE KEY` in lib/ | ___ |
| `grep clearAll` outside queue file | ___ |
| `.env.*` tracked in git | ___ |
| `Test1234` in tracked backend files | ___ |

---

## Conclusion

___
