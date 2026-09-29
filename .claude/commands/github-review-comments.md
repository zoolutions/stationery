---
description: "Use when a PR has unresolved review comments: evaluates each against the code, implements the valid fixes, pushes back on the wrong ones, and resolves every thread."
model: sonnet
argument-hint: "PR number (e.g., 123 or #123)"
allowed-tools: Bash(gh pr list:*), Bash(gh pr view:*), Bash(gh pr diff:*), Bash(gh pr comment:*), Bash(gh api:*), Bash(git log:*), Bash(git blame:*), Bash(git push:*), Bash(git commit:*), Bash(git add:*), Bash(bundle exec:*), Read, Write, Edit, Glob, Grep, Agent
---

# Review GitHub PR comments: $ARGUMENTS

## Phase 0: The PR

`PR123`, `123`, `#123` → 123; empty: `gh pr list --author=@me --head="$(git branch --show-current)" --state=open --json number,title`. Confirm with `gh pr view <n> --json title,state,url`.

## Phase 1: Unresolved threads

```bash
gh api graphql -f query='
  query($owner: String!, $repo: String!, $pr: Int!) {
    repository(owner: $owner, name: $repo) {
      pullRequest(number: $pr) {
        reviewThreads(first: 100) {
          nodes { id isResolved path line
            comments(first: 20) { nodes { databaseId body author { login } } } }
        }
      }
    }
  }' -f owner=zoolutions -f repo=stationery -F pr=<n>
```

Keep the unresolved ones: thread id, comment id, file and line, body, author. None: report and stop.

## Phase 2: Judge each

Read the file at the line first; reviewers misread diffs. Then:

| Category | Action |
|---|---|
| A real bug or missing spec | Fix it (spec first) |
| Consistency with the codebase | Fix it |
| Wrong for this code | Push back with the code that shows it |
| Against `AGENTS.md` (a runtime dependency, drawing outside `Canvas::Interface`, bytes changed where unused, a CSS layout engine, shaping in the gem) | Push back, citing the rule |
| YAGNI | Push back, say why |
| Unclear | Ask; do not implement |

`AGENTS.md` wins over a reviewer's preference, a bot's included.

## Phase 3: Fix

Edit; `bundle exec rspec <specs>` then `bundle exec rspec` (exit status); `bundle exec rubocop lib spec examples Rakefile`; `bundle exec rake metrics` if `lib/` changed; render and look at the PNG if the fix changes what is drawn; a changelog bullet if it changes what a user sees. One commit (`fix: address review feedback` with a line per fix), `git push`.

## Phase 4: Reply and resolve

```bash
gh api "repos/zoolutions/stationery/pulls/<n>/comments/<comment id>/replies" --method POST -f 'body=Fixed in <sha>: <what changed>.'
gh api graphql -f query='mutation($id: ID!) { resolveReviewThread(input: {threadId: $id}) { thread { isResolved } } }' -f id=<thread id>
```

A pushback reply gives the reason from the code. A general comment gets `gh pr comment <n> --body "..."`. Direct: no thanks, no "great point"; the SHA with every fix.

## Phase 5: Verify

Run the Phase 1 query again: every thread resolved. Report fixed / pushed back / resolved counts. A new round of comments after the push is reported to the user, not looped on.
