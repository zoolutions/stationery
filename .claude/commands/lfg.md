---
description: "Executes the full workflow for an issue or feature, from branch to pull request, with verification at each phase. Use when implementing a GitHub issue or a feature end to end."
model: opus
argument-hint: "GitHub issue number/URL, a plans/*.md file, or a feature description"
allowed-tools: Bash(gh issue view:*), Bash(gh search:*), Bash(gh issue list:*), Bash(gh pr create:*), Bash(gh pr edit:*), Bash(gh pr view:*), Bash(gh pr checks:*), Bash(bundle exec:*), Bash(bin/labels infer:*), Bash(bin/labels sync), Bash(git:*), Bash(pdftoppm:*), Read, Write, Edit, Glob, Grep, Agent
---

# LFG: an issue, end to end

`AGENTS.md` is the rulebook; this is the order to follow it in.

## Phase 0: Branch

A branch off fresh `main`, one pull request per issue or part of one. Nothing is pushed to `main`.

```bash
git fetch origin main
git switch -c issue-<number>-<slug> origin/main   # or feature/<slug> without an issue
```

## Phase 1: Understand

1. Read the issue (`gh issue view <n> --json title,body,labels,comments`) or the plan file.
   **Keep the issue's `type` and `area` labels**: Phase 7 puts them on the pull request. `/lfg` never edits the issue's own labels; the issue's lifecycle is the user's to manage. A `plans/*.md` plan carries them on its `Labels:` line. If there are none, or you were given a description, infer them: one `type` label plus `bin/labels infer <changed paths>` for the areas (`.github/LABELS.md`).
2. Write the acceptance criteria as **GIVEN / WHEN / THEN**. Do not go on until you can.
3. State in a sentence what changes for someone who uses the gem, the edge cases the issue does not name, and the code path from the document class to the bytes written.
4. Make a task list.

## Phase 2: Explore

Find the related files yourself, or with an Explore agent (`model: haiku`) when the search is broad. Read the patterns of a similar feature, its specs, its example and its docs page. Where things live is in the table at the top of `AGENTS.md`.

## Phase 3: Plan

The files to change and create, the specs that come first, the example and the README/docs pages the change touches, and whether it touches tagging, PDF/A or PDF/UA (then veraPDF runs in Phase 6). Consult the advisor before a public API, a new option name or anything a user's document would render differently.

## Phase 4: Implement (test first)

Keep a deviation log in `implementation-notes.md` (gitignored) from the first edit: one line each for **deviations** (planned X, did Y, because Z), **discoveries** and **judgment calls**, written when they happen. Take the conservative option and go on.

For each unit: a spec, seen failing (`bundle exec rspec <spec>`); the least code that passes; refactor while green.

| Never | Always |
|---|---|
| A runtime dependency or native code | Pure Ruby, stdlib only |
| A layout node, the SVG renderer or a `canvas` block reaching for `canvas.page`, operators or resources | Only what `Stationery::Canvas::Interface` names, top-left, in points |
| A feature that changes the bytes of a document that does not use it | Unused means byte for byte what it was, and the same allocations |
| An example that reads from `spec/` | Examples read from `examples/` (the docs image leaves `spec/` out) |
| Two renders compared byte for byte with a live clock | Pin the clock |
| An overflow fixture of many paragraphs | `box(break_inside: :avoid)` |

## Phase 5: Root cause (bug fixes)

Trace the document from its class to the failure: which node measured or placed what, on which page, with which font and style. `git log -S` and `git blame` for why a line is as it is; grep every caller. Fix at the earliest point that could have prevented it. No `rescue nil`, no `&.` to hide a nil you have not explained, no guard that skips drawing.

## Phase 6: Verify

All must pass before the commit:

```bash
bundle exec rspec                                  # judged by its exit status, not its summary line
bundle exec rubocop lib spec examples Rakefile     # never docs/ from the root: CI lints it
bundle exec rake metrics                           # allocations, pages and bytes against benchmark/baseline.json
bundle exec rake verify:conformance                # when tagging, PDF/A or PDF/UA is touched (local verapdf, else Docker)
```

- **Look at what is drawn.** For a change to layout or anything that renders differently: `bundle exec stationery render <example>.rb --png` (or `pdftoppm -png -r 72 file.pdf out`), then open the PNGs and look. `--debug` draws the layout rectangles. Say in the pull request what you saw.
- A metrics failure is fixed, not recorded away. `rake metrics:update` only for a change made on purpose, with the baseline's Ruby, and the commit says why.
- A new tagged example joins the `renders` of `verify:conformance` in the `Rakefile`. A conformance rule is named from the validator's profile.
- A changelog bullet under `## Unreleased` in `CHANGELOG.md` (create the heading if the last release removed it), written for someone who uses the gem; a behaviour change is named as one. The README and the docs pages stating what changed are updated with it.

Then re-read the issue: would the reporter call it resolved, and do the specs prove the cause is gone rather than hidden?

## Phase 6.5: Fable validation

Spawn the `fable-validator` agent (it is pinned to Fable) with the issue, the acceptance criteria from Phase 1 and the base branch. On **BLOCK**, fix every blocker (back to Phase 4 for code, with a failing test first), re-verify, and run the validator again. On **PASS WITH NOTES**, fix the risks you agree with and list the rest in the pull request under "Accepted risks". Put the validator's one-line verdict and its "Not verified" list in the pull request body. Do not open the pull request before a PASS or PASS WITH NOTES.

## Phase 7: Commit and pull request

Conventional commits (`feat:`, `fix:`, `perf:`, `docs:`, `test:`, `refactor:`, `chore:`), specific files added, no AI attribution. Push and open the pull request with the body in a file (`gh pr create --title "..." --label <type> --label <area> [--label <area>...] --body-file <file>`), so backticks survive. The body has:

- **Summary**, with `Closes #<n>`;
- **Test plan**: the checks run and their result, what the rendered pictures showed, the veraPDF rule when one applies;
- **Fable validation**: the verdict line, "Not verified", "Accepted risks";
- **Deviations & judgment calls**, moved from `implementation-notes.md` (then delete the file), or "None: the plan held."

**Label the PR, every time.** The `--label` flags are the issue's `type` + `area` labels from Phase 1, never a `status` label (`plan`, `epic`, ...). For a description-only run, infer them: one `type` (`.github/LABELS.md` maps conventional-commit prefixes to types) plus `bin/labels infer $(git diff --name-only origin/main...HEAD)`. Exactly one type, at least one area. `gh pr create` fails on a label that doesn't exist on GitHub: run `bin/labels sync` (or label after the fact with `gh pr edit <n> --add-label ...`).

The branch is merged when CI is green, with `main` merged in first if it moved (merged, not rebased). Never release: `bin/release` is the maintainer's.

## Phase 8: Close-out

End with the 3 to 5 decisions someone must understand to maintain the change (deviations first), and three questions the user should be able to answer before merging; offer a walkthrough if any is not obvious.

## Verification checklist

- [ ] Acceptance criteria met; specs written first and seen failing
- [ ] `rspec` exits 0, `rubocop lib spec examples Rakefile` clean, `rake metrics` passes
- [ ] `rake verify:conformance` passes, if tagging, PDF/A or PDF/UA was touched
- [ ] Rendered to PNG and looked at, if anything draws differently
- [ ] `## Unreleased` bullet; README and docs pages updated
- [ ] `fable-validator` PASS or PASS WITH NOTES, recorded in the body
- [ ] PR labelled: one `type` + at least one `area`, no `status` (`.github/LABELS.md`)
- [ ] Pull request body ends with Deviations & judgment calls; close-out delivered
