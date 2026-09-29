---
description: "Drive a set of open PRs to merge-ready, one at a time, in a given order. Merges main into each (never rebases), resolves the recurring CHANGELOG and docs/Gemfile.lock conflicts, runs /github-review-pr on each, then waits for the user to merge before advancing. With 'automerge' it merges itself once every check passes, without a human review (main requires 0 approvals)."
model: opus
argument-hint: "ordered PR list (e.g. '192 188 189'); optional 'automerge'; empty = your open PRs, oldest first"
allowed-tools: Bash(gh pr list:*), Bash(gh pr view:*), Bash(gh pr checks:*), Bash(gh pr diff:*), Bash(gh pr comment:*), Bash(gh pr edit:*), Bash(gh pr merge:*), Bash(gh api:*), Bash(gh run view:*), Bash(git:*), Bash(bundle:*), Bash(bundle exec:*), Bash(cd:*), Read, Write, Edit, Glob, Grep, Agent, Skill, TaskCreate, TaskUpdate, TaskGet, TaskList, ScheduleWakeup
---

# Finish PRs: $ARGUMENTS

Make each pull request merge-ready in order, and let the user merge. This command does not merge unless `automerge` was passed.

## Phase 0: The list

- Numbers in order (`#192`, `PR192` accepted); `automerge` anywhere lets this command merge each pull request itself (2e). That merge has no human review: `main` requires 0 approvals, so the only reviews are `/github-review-pr` and the `fable-validator`.
- Empty: `gh pr list --author=@me --state=open --limit 100 --json number,title,headRefName,baseRefName,createdAt`, oldest first.
- A pull request stacked on another is pointed at `main` (`gh pr edit <n> --base main`) before its parent merges: GitHub closes a pull request whose base branch is deleted.

One task per pull request. Say: `Finishing N PRs: #a → #b → #c. Mode: pause-for-merge | automerge.`

## Phase 1: A worktree per branch

Use an existing worktree on the branch (`git worktree list`), else `git fetch origin <branch>` and `git worktree add .claude/worktrees/finish-<n> <branch>`. Never touch the main checkout.

## Phase 2: Per pull request

### 2a. Merge `main` in (merged, not rebased: `AGENTS.md`)

```bash
git fetch origin main
git merge origin/main
```

Conflicts resolved here, and only these:

- **`CHANGELOG.md`**: keep both sides' bullets under `## Unreleased`. Where both sides changed the same bullet, `main`'s is kept. Then read the section again: a union can keep the wrong copy, drop a bullet or duplicate one. No conflict markers may remain.
- **`docs/Gemfile.lock`**, when the only conflict is the `stationery (X.Y.Z)` pin: take `main`'s file and set the pin to `lib/stationery/version.rb`'s version in BOTH places it appears, under `PATH` and under `CHECKSUMS`. Never run `bundle lock`.
- **`benchmark/baseline.json`**: take `main`'s, then `bundle exec rake metrics`; if this branch's change moves the numbers on purpose, record again with `rake metrics:update` (the baseline's Ruby) and say why in the commit.

Any other conflicted file: `git merge --abort`, report it, ask.

### 2b. Checks, then push

`bundle exec rspec`, `bundle exec rubocop lib spec examples Rakefile`, `bundle exec rake metrics`. All pass: commit the merge and `git push` (a merge never needs force). A check that fails after merging `main` is fixed before the push, through 2c's `/github-review-pr` (which runs `/github-review-failures`); if it cannot be fixed, the pull request is marked `needs-user` and nothing is pushed.

### 2c. Review pass

Invoke `/github-review-pr <n>` (Skill tool): CI failures, then review comments. A pull request it cannot finish is marked `needs-user`; go on to the next and come back.

### 2d. Merge-ready

`main`'s ruleset requires only Lint, Ruby 3.4, Ruby 4.0 and Docs site, so GitHub's "mergeable" says nothing about the Metrics gate, veraPDF or Rails. `AGENTS.md` says merged when CI is green, so:

- `gh pr checks <n> --json name,bucket`: EVERY check in bucket `pass` or `skipping`. Any `pending`: wait (`ScheduleWakeup`, about 180s) and ask again. Any `fail` or `cancel`: back to 2c.
- `gh pr view <n> --json mergeable,reviewDecision`: `MERGEABLE`, no `CHANGES_REQUESTED`.

### 2e. Hand off

Run the `fable-validator` agent on the combined diff first. On BLOCK do not open or merge: mark it `needs-user` and report the blockers instead of calling it ready.

- automerge: only once 2d holds, a plain `gh pr merge <n> --merge` (never `--auto`: GitHub would merge on the four required checks alone, whatever the others do). No human reviews it. Then Phase 3.
- Otherwise: report it merge-ready with its URL and one line of what is in it, and wait.

## Phase 3: Wait, then advance

- automerge: confirm `gh pr view <n> --json state` is `MERGED`.
- Otherwise: on the next turn check the state; if not merged, report and stop.

On a merge, go to the next pull request and start at 2a: it absorbs what just landed. A pull request merged out of order is dropped from the list.

## Phase 4: Report

| PR | Result | Note |
|---|---|---|
| #a | merged / merge-ready / awaiting merge / needs-user | one line |

Then what the user has to do. Never cut a release: that is the maintainer's, with `bin/release`.

## Never

- Rebase, or force-push.
- Resolve a conflict outside the three files above.
- Merge in the default mode, merge with `--auto`, or merge while any check is pending or failing.
- Re-implement `/github-review-pr` or its two children.
