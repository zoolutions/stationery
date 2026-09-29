# Performance

**Measure before the change, measure after, report both.** A claim without a same-machine before and after is not made; `/perf` does it with `main` in a worktree.

## The two measures

| Task | Measures | In CI |
|---|---|---|
| `bundle exec rake metrics` | Allocations, pages and bytes of fixed documents against `benchmark/baseline.json` | Yes, the gate (Ruby 3.4) |
| `bundle exec rake bench` | Time against Prawn (and sghtmltopdf when installed) | No: wall time on a shared machine is noise |

Also: `PROFILE=1 bundle exec ruby -Ilib benchmark/profile.rb` (StackProf), `bundle exec rake memory` (long documents).

## Rules

- A document that does not use a feature is byte for byte what it was and allocates what it did.
- The baseline is recorded again (`rake metrics:update`, with the Ruby the baseline names) only for a change made on purpose, and the commit says why. A version bump lengthens the version string, so the release preparation records it again.
- Hot paths: text wrapping and measurement (`text/`, `fonts/`), layout and pagination (`layout/`), tables, images, the writer and its compression (`pdf/`). A change there comes with numbers.
- Never trade correctness, conformance or a tested behaviour for a win the numbers do not show; never optimise a path the profile does not show hot.
- Numbers within the benchmark's ± are "within noise"; say whether a number is one operation or a whole render.
