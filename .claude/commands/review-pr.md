---
description: Review a GitHub pull request against Stationery's rules
model: opus
argument-hint: "PR URL or number (e.g., 5 or https://github.com/zoolutions/stationery/pull/5)"
---

# PR review

Review the pull request for what `AGENTS.md` requires. Be concise.

1. `gh pr view <n> --json title,body,files,statusCheckRollup` and `gh pr diff <n>`.
2. Sort the files: gem (`lib/`), specs, examples, benchmark and baseline, README/docs, changelog.
3. Check the rules below; read the code around each change, not only the diff.

## What to check

| Wrong | Right |
|---|---|
| A runtime dependency, native code, a new gem in the gemspec | Pure Ruby, stdlib only |
| A node, the SVG renderer or a `canvas` block using `canvas.page`, operators, resources | Only `Stationery::Canvas::Interface` |
| Bytes or allocations of a document that does not use the feature changed | Byte for byte what it was |
| `benchmark/baseline.json` re-recorded without a reason in the commit | Recorded only for a change on purpose, with the baseline's Ruby |
| A PDF/A or PDF/UA claim argued in prose | A veraPDF run, and the rule from its profile named |
| A new tagged example missing from `verify:conformance`'s `renders` | Added to the `Rakefile` |
| A layout change with no word on what the render looked like | The PR says what the PNG showed |
| No `## Unreleased` bullet, or one written for maintainers | A bullet for someone who uses the gem; behaviour changes named |
| README or docs page left stating the old behaviour | Updated with it |
| An example reading from `spec/` | Reads from `examples/` |
| Unsupported CSS approximated | `Warnings::UnsupportedCss` |
| `rescue` that swallows, `&.` hiding an unexplained nil | Specific handling, a warning, or the cause fixed |

## Output

```
## Files requiring manual review
| File | Reason |

## Critical issues
- `lib/stationery/layout/table.rb:45` — one line

## Suggestions (non-blocking)

## Verdict
**Approve / Request Changes / Comment** — one line
```

Local checks when needed: `bundle exec rspec <files>`, `bundle exec rubocop lib spec examples Rakefile`, `bundle exec rake metrics`.
