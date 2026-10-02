---
description: "Investigates the codebase, designs a solution, and produces a durable plan: a GitHub issue or a plan markdown under plans/. Read-only: never edits the gem. Use before /lfg for anything non-trivial."
model: fable
argument-hint: "issue <feature or problem> | md <feature or problem> | <feature or problem>"
allowed-tools: Bash(gh issue create:*), Bash(gh issue edit:*), Bash(bin/labels infer:*), Bash(bin/labels sync), Bash(gh issue list:*), Bash(gh issue view:*), Bash(gh search:*), Bash(gh label list:*), Bash(git log:*), Bash(git diff:*), Bash(git branch:*), Bash(date:*), Read, Grep, Glob, Write, Agent, AskUserQuestion
---

# Plan: design expensive, execute cheap

The thinking happens here, on Fable; the execution happens later (`/lfg` on Opus, specialists on Sonnet). That only works if the plan is **self-contained**: an executor without this session must be able to carry it out without guessing.

## Output from $ARGUMENTS

| Starts with | Artifact |
|---|---|
| `md` or `file` | `plans/YYYY-MM-DD-<slug>.md` (date from `date +%F`), left uncommitted |
| anything else | A GitHub issue (feeds `/lfg <number>`) |

## Constraints

- Read-only for the gem: no edits, commits or branches. The only file you may write is a new plan under `plans/`.
- Never copy a secret into a plan.
- Dedupe first: `gh issue list --search "<keywords>"`.

## Phase 1: Investigate

1. Fan out Explore agents with `model: haiku` for file discovery and naming sweeps, and `model: sonnet` agents when a subsystem needs reading and summarising. Independent ones in parallel.
2. Read the load-bearing files yourself; do not design from summaries.
3. Read `AGENTS.md` (the canvas rule, the metrics gate, the validators, what is out of scope) and `git log` for related work.

## Phase 2: Unknowns

1. List what the request leaves open: the DSL name and options, defaults, what a document that does not use the feature does (it must be byte for byte unchanged), tagging and PDF/A/UA, what the README and docs say today, anything without precedent here.
2. Ask the user with AskUserQuestion, one question at a time, most consequential first, each with options and a recommended default. Skip what the code or `AGENTS.md` already answers; none is fine when nothing is open.
3. Record the answers as `Settled in interview:` bullets.

## Phase 3: Design

Two or three approaches with real trade-offs; pick one and say why the others lost. It keeps the gem pure Ruby with no runtime dependency, draws only through `Stationery::Canvas::Interface`, costs nothing where unused, and stays out of what `AGENTS.md` puts out of scope (a CSS layout engine, shaping and bidi in the gem, native code, lossy WebP). Name the specs, the example, the metrics expectation and the validator that settles each standards claim.

## Phase 4: The plan

```markdown
# <Title>

## Problem / Goal
## Context (read these first)
<`path` — why it matters. No "as discussed".>
## Decision
<Chosen approach, the alternatives and why they lost, then `Settled in interview:` bullets.>
## Implementation steps
<Ordered and small; specs before the code they cover; exact files, the example, the README/docs pages, the `## Unreleased` bullet.>
## Verification gates
- `bundle exec rspec` exits 0
- `bundle exec rubocop lib spec examples Rakefile` clean
- `bundle exec rake metrics` passes (or: the baseline is recorded again, and why)
- `bundle exec rake verify:conformance` (when tagging or PDF/A/UA is touched)
- Rendered with `bundle exec stationery render <file>.rb --png` and looked at: what should be seen
## Out of scope
## Execution
`/lfg <issue-number>` (or `/lfg plans/<file>.md`)
```

Create an issue with `gh issue create --title "..." --body-file <tmpfile>`, then label it.

### Label the issue

Every `/plan` issue is labelled: `/lfg` copies its `type` and `area` labels onto the pull request, so getting them right here is what labels the PR. The taxonomy is `.github/labels.yml`; `.github/LABELS.md` explains the groups.

1. **`plan`**: always.
2. **One type label**: `enhancement` by default; `bug` for a defect, `performance` for a speed-up, `tech-debt` for cleanup, `security` for a vulnerability or hardening, `chore` for CI/tooling/config, `documentation` for docs only, `dependencies` for bumps.
3. **Area labels**: `bin/labels infer <every path in the Context section>`, plus any area the path map can't see. Never zero.

```bash
gh issue edit <number> --add-label plan --add-label <type> --add-label <area> [--add-label <area>...]
```

(or pass the same labels as `--label` flags to `gh issue create`). If a label is missing on GitHub, run `bin/labels sync`; never `gh label create` a label that isn't in `.github/labels.yml`.

(For a plan written to a markdown file instead of an issue: put a `Labels: <type>, <area>...` line under the title so `/lfg` can carry them to the PR.)

## Phase 5: Handoff

The issue link or file path, the approach in two or three sentences, the execute command. Then stop.
