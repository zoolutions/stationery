---
description: "Drive a set of open PRs to merge-ready, one at a time, in a given order. Merges main into each (never rebases), resolves the recurring CHANGELOG and docs/Gemfile.lock conflicts, runs /github-review-pr on each, then waits for the user to merge before advancing."
model: opus
argument-hint: "ordered PR list (e.g. '192 188 189'); optional 'automerge'; empty = your open PRs, oldest first"
allowed-tools: Bash(gh pr list:*), Bash(gh pr view:*), Bash(gh pr checks:*), Bash(gh pr diff:*), Bash(gh pr comment:*), Bash(gh pr edit:*), Bash(gh pr merge:*), Bash(gh api:*), Bash(gh run view:*), Bash(git:*), Bash(bundle:*), Bash(bundle exec:*), Bash(cd:*), Read, Write, Edit, Glob, Grep, Agent, Skill, TaskCreate, TaskUpdate, TaskGet, TaskList, ScheduleWakeup
---

# Finish PRs: $ARGUMENTS

Make each pull request merge-ready in order, and let the user merge. This command does not merge unless `automerge` was passed.

## Phase 0: The list

- Numbers in order (`#192`, `PR192` accepted); `automerge` anywhere enables `gh pr merge --auto --merge` once green.
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
- **`docs/Gemfile.lock`**, when the only conflict is the `stationery (X.Y.Z)` path pin: take `main`'s file and set the pin to `lib/stationery/version.rb`. Never run `bundle lock`.
- **`benchmark/baseline.json`**: take `main`'s, then `bundle exec rake metrics`; if this branch's change moves the numbers on purpose, record again with `rake metrics:update` (the baseline's Ruby) and say why in the commit.

Any other conflicted file: `git merge --abort`, report it, ask.

### 2b. Checks, then push

`bundle exec rspec`, `bundle exec rubocop lib spec examples Rakefile`, `bundle exec rake metrics`. Commit the merge and `git push` (a merge never needs force).

### 2c. Review pass

Invoke `/github-review-pr <n>` (Skill tool): CI failures, then review comments. A pull request it cannot finish is marked `needs-user`; go on to the next and come back.

### 2d. Merge-ready

`gh pr view <n> --json mergeable,mergeStateStatus,reviewDecision` and `gh pr checks <n> --json name,bucket`: `MERGEABLE`, no failing check, no `CHANGES_REQUESTED`. `BLOCKED` with all else green is the approval gate.

### 2e. Hand off

Run the `fable-validator` agent on the combined diff first; do not open or merge on BLOCK.

- automerge: `gh pr merge <n> --auto --merge`, then Phase 3.
- Otherwise: report it merge-ready with its URL and one line of what is in it, and wait.

## Phase 3: Wait, then advance

- automerge: poll `gh pr view <n> --json state` with `ScheduleWakeup` (about 180s), until `MERGED`.
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
- Merge in the default mode.
- Re-implement `/github-review-pr` or its two children.
