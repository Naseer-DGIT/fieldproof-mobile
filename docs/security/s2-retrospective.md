# S2 Retrospective

- **Date:** 2026-09-18
- **Format:** individual, written
- **Sprint:** S2

The purpose of this file is to carry forward what went wrong so S3 does
not repeat it.

---

## What went well

1. **The S1 foundation held.** The encrypted queue, KeyStore, Dio client,
   and BLoC pattern all worked unchanged. S2 added features, not
   infrastructure.
2. **End-to-end signature verification worked the first time it was
   tested end-to-end.** The Python script caught nothing that the Dart
   code had not already handled.
3. **The `EventPoster` / `DrainCaller` seam made tests deterministic.**
   Once the worker accepted a function instead of a class, testing the
   six outcomes became trivial.
4. **CI needed no changes.** The workflow written in S1 Day 9 carried
   over unchanged.

## What did not go well

1. **`psycopg2` and `bcrypt` versions wasted time.** Both are known
   Python 3.14 compatibility problems. Should check package support
   before installing.
2. **Day 4 and Day 6 test fakes both had field/method name collisions.**
   `pending` field vs `pending()` method. Same mistake twice.
3. **`ApiResult` was designed as static-only**, which blocked testing
   until it was rewritten. A static-only API is untestable when it does
   the network call you need to fake.
4. **The S2 Day 8 review was committed with 55 placeholders** because
   the placeholder check was not run before `git add`. The check exists
   precisely to catch this.
5. **Day 5 through Day 7 each needed one extra fix commit.** Small
   issues — missing `event_id`, missing import, sealed class — but each
   cost a round trip.

## Action items for S3

| # | Action | Applied in |
|---|--------|-----------|
| 1 | Check Python package support before `pip install` | S3 |
| 2 | Never name a test fake field the same as an inherited method | S3 onward |
| 3 | Any API class that does I/O must accept injection (function or interface) | S3 |
| 4 | Run a placeholder scan on any doc before `git add` (see the `docs/` check script in Step 4) | S3 onward |
| 5 | Run `flutter analyze <file>` after every full-file overwrite | S3 onward |
| 6 | Prefer full-file overwrite to `python3` patches when the anchor is not unique | S3 |
| 7 | Add integration tests for the endpoint before writing the mobile client | S3 onward |

## Questions to carry forward

- Should `s2-review.md` and the summary live in mobile or backend? S1
  put them in mobile; S2 followed. Backend has its own
  `docs/security/` with the threat register. There are now two places
  to look for sprint docs.
- Is the "one branch per day" pattern worth the merge overhead? Day 8
  was the only day with a separate branch. It added a merge commit and
  a tag move. For a solo sprint, committing directly to
  `sprint/s2-attendance` is simpler.
- When S3 adds RBAC, should the role claim in the JWT be enough, or
  should every request re-check the role from the database? The JWT is
  valid for 1h — a role change takes up to 1h to propagate. Decide in
  S3.
