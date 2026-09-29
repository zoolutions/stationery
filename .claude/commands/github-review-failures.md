---
description: "Use when CI checks are failing on a PR: fetches the failure logs, finds the causes, fixes them locally and pushes until CI is green."
model: sonnet
argument-hint: "PR number (e.g., 41 or #41)"
allowed-tools: Bash(gh pr list:*), Bash(gh pr view:*), Bash(gh pr checks:*), Bash(gh pr diff:*), Bash(gh api:*), Bash(gh run view:*), Bash(git log:*), Bash(git diff:*), Bash(git push:*), Bash(git commit:*), Bash(git add:*), Bash(bundle exec:*), Read, Write, Edit, Glob, Grep, Agent
---

# Fix GitHub CI failures: $ARGUMENTS

## Phase 0: The PR

`PR41`, `41`, `#41` → 41; empty: `gh pr list --author=@me --head="$(git branch --show-current)" --state=open --json number,title`. Confirm with `gh pr view <n> --json title,state,url,mergeable`. `CONFLICTING`: stop and hand to `/github-review-pr` (its Phase A0 merges).

## Phase 1: What failed

`gh pr checks <n> --json name,bucket,link`. The jobs (`.github/workflows/main.yml`):

| Check | Runs | Locally |
|---|---|---|
| `Lint` | `bundle exec rubocop`, `gem build stationery.gemspec --strict` | `bundle exec rubocop lib spec examples Rakefile` |
| `Ruby 3.4`, `Ruby 4.0` | `bundle exec rspec`, `bundle exec rake examples` | the same |
| `Metrics gate` | `bundle exec rake metrics` on Ruby 3.4 | the same, with the baseline's Ruby |
| `PDF/A and PDF/UA (veraPDF)` | `rake verify:conformance`, `verify:factur_x`, `verify:signature` | the same (local `verapdf` or Docker) |
| `Rails` | `rake spec:rails` under `gemfiles/rails.gemfile` | `BUNDLE_GEMFILE=gemfiles/rails.gemfile bundle exec rake spec:rails` |
| `Docs site` | CSS build, rubocop and rspec inside `docs/` | `cd docs && bundle exec rubocop && bundle exec rspec` |

Run and job IDs are in the check link (`.../actions/runs/<RUN>/job/<JOB>`). Nothing failing: report and stop.

## Phase 2: Logs

`gh run view <RUN> --job=<JOB> --log-failed`; if unclear, the full `--log`.

## Phase 3: Causes

- **Rubocop**: file, line, cop. Fix the code; no `rubocop:disable` to get past it.
- **Specs**: judge by the exit status. Read the failing example, its error and the relevant frames; environment or code?
- **Examples render**: an example raised; run it with `bundle exec stationery render examples/<file>.rb`.
- **Metrics**: which document grew, in allocations, pages or bytes. A document that does not use the change must be byte for byte what it was: find why it moved. Re-record (`rake metrics:update`) only for a change made on purpose, with the baseline's Ruby, and say why in the commit.
- **veraPDF**: the rule from the profile (for example 7.18.5-1); fix the output, then say which rule in the PR.
- **Gem build**: a file the gemspec expects, or a warning `--strict` refuses.
- **Docs**: a page, its `.md` twin, or a README/CHANGELOG section a page embeds.

## Phase 4: Fix and verify locally

Lint first, then specs, then the rest. Run what failed until it passes, then `bundle exec rspec` whole.

## Phase 5: Commit and push

`git add <files>`, `git commit -m "fix(ci): <what>"`, `git push`. No AI attribution.

## Phase 6: Report

`gh pr checks <n> --json name,bucket`: what was fixed, what is running. Do not poll in a loop. A failure already on `main` is noted, not fixed here; a spec that passes locally and fails in CI is reported as possibly flaky, not worked around.
