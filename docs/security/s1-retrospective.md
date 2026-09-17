# S1 Retrospective

- **Date:** 2026-09-17
- **Format:** individual, written
- **Sprint:** S1

The purpose of this file is to carry forward what went wrong so S2 does
not repeat it.

---

## What went well

1. **Encrypted storage worked the first time.** SQLCipher + `flutter_secure_storage`
   behaved as documented. The attack lab confirmed the encryption is real,
   not just configured.
2. **The attack lab found a real bug.** Opening the DB at startup was missed
   in Day 4 cleanup; the lab on Day 7 caught it before it could silently break
   S2's offline queue. A test that reads its own output would not have caught it.
3. **ADR-0001 (BLoC) paid off immediately.** The shell's tab-state transition
   is testable in isolation. No widget needed to verify it.
4. **Branch protection + CI work.** Direct push to `main` is blocked. The
   deferred S0 protection was finally applied once the check names existed.

## What did not go well

1. **`psycopg2` on Python 3.14.** Spent significant time on a driver that had
   no wheels. Should have checked `pip show psycopg2-binary` before writing any
   migration.
2. **Homebrew Postgres shadowed Docker on port 5432.** Two servers on the same
   port created a confusing connection error that looked like a code bug.
3. **iOS deployment target was 11.0 by default.** `flutter_secure_storage`
   requires 12.0. The error was clear but cost a rebuild cycle.
4. **The Day 4 report was written but the DB path was never exercised end to
   end.** The report described the plan rather than the run. Day 7's attack lab
   is what actually validated it.
5. **Committing at day boundaries slipped.** Days 4–7 sat uncommitted until
   they were split by file. Future sprints: commit at end of each day.
6. **CI Flutter version drifted from local.** Workflow pinned 3.24.0 while
   pubspec required Dart 3.12.2. The mismatch surfaced only on first push.
   Pin both sides from day 1.

## Action items for S2

| # | Action | Applied in |
|---|--------|-----------|
| 1 | Commit at the end of every day, not at the end of a group of days | S2 Day 1 onward |
| 2 | Run `git status --short` before every commit | S2 |
| 3 | Verify dependencies support the installed Python/Flutter version before installing | S2 |
| 4 | Write the "run" evidence, not the "plan", in lab reports | S2 onward |
| 5 | Keep the local Postgres stopped; only Docker Postgres runs | ongoing |
| 6 | Pin CI toolchain to the local version from the first commit | S2 Day 1 |
| 7 | Extend the `s1-review.md` pattern to each sprint — one review doc per sprint | S2 |

## Questions to carry forward

- Should `s1-review.md` and the sprint summary live in the mobile repo, or in a
  shared `docs/` in the backend repo where the ADRs and threat register live?
- Is the split between `s0-*` and `s1-*` in commit messages useful, or is it
  noise once branches carry the sprint?
- When S2 adds the auth flow, do we add a second BLoC, or extend `AppShellBloc`?
  ADR-0001 does not answer this yet.
