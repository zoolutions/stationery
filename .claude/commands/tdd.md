---
description: "Use when implementing a feature or fixing a bug: RED-GREEN-REFACTOR, a failing spec first, the least code that passes, then refactor."
model: sonnet
---

# TDD

`AGENTS.md`: a spec first, seen failing, then the change.

## The cycle

1. **RED**: a spec for the behaviour; run it and see it fail for the reason you expect (`bundle exec rspec spec/stationery/<file>_spec.rb`). A spec that passes before the change tests nothing.
2. **GREEN**: the least code that passes.
3. **REFACTOR**: while green.
4. Next case. At the end, `bundle exec rspec` whole, judged by its exit status.

A bug gets a spec that reproduces it before anything is fixed.

## Where the spec goes

| Change | Spec |
|---|---|
| A class in `lib/stationery/` | `spec/stationery/<same path>_spec.rb` |
| A whole document (layout, pagination, tagging, outputs together) | `spec/integration/` |
| Rails (helpers, `render pdf:`) | `spec/rails/`, run with `BUNDLE_GEMFILE=gemfiles/rails.gemfile bundle exec rake spec:rails` |
| What a user asserts on | The matchers and inspector in `lib/stationery/testing/` |

## How Stationery specs assert

- On what was laid out and drawn, through the testing helpers (text and its position, pages, structure), not on the bytes of a whole PDF.
- Byte-for-byte comparisons pin the clock, or they differ when a second turns.
- A document that does not use the feature: assert it is unchanged (the metrics gate checks the fixed documents; a spec checks yours).
- An overflow fixture uses `box(break_inside: :avoid)`; many paragraphs split across pages instead.
- Every example is painted on a non-PDF canvas by `spec/stationery/document_paint_on_spec.rb`: a node that reaches for PDF fails there.
- Edge cases: empty text and zero sizes, a word wider than the column, a row taller than a page, missing glyphs, the last line of a page.

## Checklist

- [ ] Each spec seen failing first
- [ ] `bundle exec rspec` exits 0
- [ ] `bundle exec rubocop lib spec examples Rakefile` clean
- [ ] `bundle exec rake metrics` passes
