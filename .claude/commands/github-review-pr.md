---
description: "Use when a PR needs a full pass: merge conflicts with main first, then CI failures, then unresolved review comments. Conflicts first so CI is read for what will merge; failures before comments because comment fixes start new CI runs that bury the original failures."
model: opus
argument-hint: "PR number (e.g., 156 or #156)"
allowed-tools: Bash(gh pr list:*), Bash(gh pr view:*), Bash(gh pr checks:*), Bash(gh pr checkout:*), Bash(gh pr diff:*), Bash(gh pr comment:*), Bash(gh api:*), Bash(gh run view:*), Bash(git log:*), Bash(git blame:*), Bash(git diff:*), Bash(git status:*), Bash(git switch:*), Bash(git fetch:*), Bash(git merge:*), Bash(git merge-tree:*), Bash(git rev-parse:*), Bash(git push:*), Bash(git commit:*), Bash(git add:*), Bash(bundle exec:*), Bash(bundle install:*), Bash(cd:*), Read, Write, Edit, Glob, Grep, Agent
---

# Review GitHub PR (full pass): $ARGUMENTS

Three phases, strictly in this order: **A0** merge conflicts, **A** CI failures, **B** review comments. The only way back is a new conflict (to A0) or a new failure (to A).

## Phase 0: The PR number

`PR156`, `156`, `#156` → 156. Empty: `gh pr list --author=@me --head="$(git branch --show-current)" --state=open --json number,title`; one match is it, otherwise ask. Confirm with `gh pr view <n> --json title,state,url`; a merged one ends the pass.

## Phase A0: Merge conflicts

`gh pr view <n> --json mergeable,mergeStateStatus,baseRefName`:

| `mergeable` | Action |
|---|---|
| `MERGEABLE` | Phase A |
| `UNKNOWN` | Check locally: `git fetch origin <base>`, `git fetch origin pull/<n>/head`, verify both with `git rev-parse --verify <ref>^{commit}`, then `git merge-tree --write-tree --name-only origin/<base> FETCH_HEAD`. Clean: Phase A. Conflicts: resolve. |
| `CONFLICTING` | Resolve |

Resolution:

1. `gh pr checkout <n>` on a clean tree (dirty: stop and ask).
2. `git fetch origin <base>` and `git merge origin/<base>`: merged, never rebased (`AGENTS.md`).
3. Resolve each file by reading both sides and keeping both intents; never a blanket `--ours`/`--theirs` on source.
   - `CHANGELOG.md`: both sides' bullets under `## Unreleased`; where both changed the same bullet, `main`'s is kept; read the section again after.
   - `lib/stationery/version.rb`: only the release preparation changes it; take the base's.
   - `docs/Gemfile.lock`: never hand-merge, never `bundle lock`; take the base's and set the `stationery (X.Y.Z)` pin to `version.rb`, or `cd docs && bundle install` if the branch changed real dependencies.
   - `benchmark/baseline.json`: take the base's, then `bundle exec rake metrics`.
4. Before pushing: `bundle exec rspec`, `bundle exec rubocop lib spec examples Rakefile`, `bundle exec rake metrics`, and `cd docs && bundle exec rspec` if `docs/` was involved.
5. Commit the merge (the standard message, plus a line for any non-obvious choice) and `git push`.

A conflict whose right combination is not decidable from the code: stop and ask.

## Phase A: `/github-review-failures`

Invoke it with the same argument (`.claude/commands/github-review-failures.md`). Go on only when CI is green, or pending with nothing failed on this commit, or failing for a cause not on this branch (say so). Failures on this branch that persist: report and ask.

## Phase B: `/github-review-comments`

Invoke it (`.claude/commands/github-review-comments.md`). Done when every thread has a reply and is resolved, and the fixes are pushed.

## Phase C: Report

Re-check mergeability first (the base may have moved: back to A0). Then:

1. A0: conflicted files and how each was resolved, the merge SHA, or "clean".
2. A: failures fixed, with SHAs.
3. B: comments accepted (SHAs), pushed back on (why), unresolved count (0).
4. End state: mergeability and `gh pr checks <n> --json name,bucket`.
5. What is left for the user.
