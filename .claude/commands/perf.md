---
description: "Measure the current branch against main: time with rake bench, allocations, pages and bytes with rake metrics. Use when a change touches text, layout, fonts, images or the writer, or when asked to measure performance."
model: sonnet
argument-hint: "optional: one benchmark script (e.g. table_50_pages)"
---

# Performance

Measure, don't guess: a same-machine before and after, or no claim.

## 1. `main` in a worktree (before)

```bash
git fetch origin main
git worktree add --detach .claude/worktrees/perf-main origin/main
cd .claude/worktrees/perf-main && bundle install --quiet
bundle exec rake bench > ../perf-before.txt
bundle exec rake metrics > ../perf-before-metrics.txt
```

## 2. The branch (after)

```bash
bundle exec rake bench > .claude/worktrees/perf-after.txt
bundle exec rake metrics > .claude/worktrees/perf-after-metrics.txt
git worktree remove --force .claude/worktrees/perf-main
```

One script alone: `bundle exec ruby -Ilib benchmark/<name>.rb` in both trees. Where time goes: `PROFILE=1 bundle exec ruby -Ilib benchmark/profile.rb`. What long documents hold: `bundle exec rake memory` (not in CI).

## 3. Report honestly

- `rake bench` gives time against Prawn (and sghtmltopdf when installed): i/s with its ±; within the ± is "within noise".
- `rake metrics` gives allocations, pages and bytes per fixed document; these are what CI holds (time is noise on a shared machine). Pages must not change; bytes and allocations of a document that does not use the change must not move.
- Say whether you measured a single operation or a whole render.
- No baseline: say "measured after only".

## 4. Keep it

- [ ] Before and after in the pull request body
- [ ] `rake metrics` passes; a baseline recorded again (`rake metrics:update`, the baseline's Ruby) only for a change on purpose, with the reason in the commit
- [ ] A `perf:` bullet under `## Unreleased` when a user would notice

Argument (`$ARGUMENTS`): a script name runs only `benchmark/$ARGUMENTS.rb` in both trees.
