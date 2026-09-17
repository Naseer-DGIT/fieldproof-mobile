# S2 — Core Attendance: Sprint Summary

- **Sprint:** S2 (Days 1–10)
- **Branch:** `sprint/s2-attendance`
- **Dates:** 2026-09-17 → 2026-09-18
- **Author:** Naseer
- **Related:** ADR-0001, ADR-0002, threat_register.md, DATA_CLASSIFICATION.md

---

## Goal

Deliver end-to-end offline attendance: authentication, device binding,
signed check-in/check-out events written to an encrypted local queue, and
a sync worker that drains the queue against a signature-verifying server.

---

## Deliverables

| Day | Deliverable | Repo | Commit |
|-----|-------------|------|--------|
| 1 | Auth BLoC + login screen + JWT endpoint | both | `cb69b2d`, `5467bfb` |
| 2 | Session lifecycle + 401 auto-logout + shell wiring | mobile | `a4e6a70` |
| 3 | Device registration (Ed25519 keypair + binding) | both | `5c2d947`, `618f3bf` |
| 4 | Check-in/out UI + signed event queue | both | `b4f7029`, `94481d8` |
| 5 | Backend POST /attendance/events with Ed25519 verification, idempotency, chain check | backend | `5e92558` |
| 6 | Mobile sync worker (accepted/duplicate/rejected/conflict/retry) | mobile | `7568266` |
| 7 | Exponential backoff + sync on app resume | mobile | `f01436b` |
| 8 | Attendance feature security review | mobile | `4084d96` |
| 9 | CI verification carried over from S1 | both | `9a53b30` |
| 10 | Summary, retrospective, PR, tag | mobile | *(this PR)* |

---

## What was built

### Authentication

- `/api/v1/auth/login` returns a JWT (1h TTL) with `sub`, `tenant`, `role`
- `/api/v1/auth/me` returns the current user
- Mobile stores the token in KeyStore, never in shared_preferences or logs
- 401 responses trigger auto-logout via `AuthSignals` stream

### Device binding

- Ed25519 keypair generated on first launch via `cryptography`
- Private key stored in hardware-backed KeyStore
- Public key uploaded to `/api/v1/devices/register` (idempotent)
- Previous devices revoked, not deleted

### Attendance

- Check-in, check-out, break-start, break-end events
- Each event signed with the device private key over canonical JSON
- `previous_event_hash` chains events per device
- Events written to SQLCipher `attendance_queue` table
- `sync_status`: pending / synced / rejected / conflict

### Sync

- `SyncWorker.drain()` processes pending rows in order
- Stops on first retryable failure, first conflict
- Rejected rows marked and skipped
- BLoC retries with exponential backoff (30s → 10min)
- `SyncOnResume` triggers sync when the app returns to foreground

### Server verification

Order enforced on every event:
1. Authenticate principal
2. Resolve active device
3. Decode signed bytes
4. Verify Ed25519 signature
5. Cross-check body vs payload fields
6. Enforce idempotency (event_id, idempotency_key)
7. Enforce chain (`previous_hash` == last event_id for this device)
8. Persist

---

## Verification

- `flutter analyze` → No issues found
- `flutter test` → 30 tests passing
- `scripts/test_attendance_events.py` → ALL PASS (valid, duplicate, bad signature, chain mismatch, chained event)
- CI green on `sprint/s2-attendance`
- Branch protection active on `main` for both repos

---

## Findings resolved during the sprint

| # | Finding | Resolution |
|---|---------|-----------|
| F-1 | Missing `event_id` column on `attendance_events` model | Added column + unique constraint; migration applied |
| F-2 | `bcrypt` 4.2 incompatible with `passlib` 1.7.4 | Pinned `bcrypt==4.0.1` |
| F-3 | Handler did not set `event_id` on insert | Set on `AttendanceEvent(...)`; tightened `IntegrityError` handling |
| F-4 | `ApiResult` is static-only, could not be faked in tests | Added `EventPoster`/`DrainCaller` typedefs for injection |
| F-5 | Sealed `ApiFailure` had no 409 case | Added `ConflictFailure` + Dio interceptor mapping |
| F-6 | Test fakes declared `pending` colliding with `pending()` method | Renamed to `pendingCountValue` |

---

## Accepted limitations

1. **Private key in process memory during signing.** Unavoidable without hardware signing APIs. Documented in ADR-0002.

2. **Chain scoped to device, not user.** Revoked and re-registered device starts a new chain. Out of scope for S2.

3. **Retry count has no cap.** Backoff caps at 10 minutes but never gives up. `max_attempts` + `dead_letter` deferred to S5+.

---

## Explicitly out of scope (moved to later sprints)

- RBAC enforcement (S3)
- OWASP AppSec lab (S4)
- TLS pinning, KMS, backup/DR (S5)
- API pentest (S6)
- Analytics and reports (S7)
- Mobile MASVS/MASTG (S8)
- MobSF static analysis (S9)
- Frida runtime testing (S10)
- Certificate pinning (S11)
- CI/CD supply chain hardening (S12–S14)

---

## Metrics

- Commits on the sprint branch: 18
- Test files: 8
- Tests: 30
- Backend endpoints added: 5 (`/auth/login`, `/auth/me`, `/auth/logout`, `/devices/register`, `/devices/me`, `/attendance/events` GET + POST)
- Threat register entries closed or mitigated: T-003, T-004, T-005, T-009, T-011, T-015
