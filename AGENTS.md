# AGENTS.md

What a contributor to Stationery, human or not, has to know and cannot read off the code. The docs site under `docs/` has an `AGENTS.md` of its own for writing its pages.

## What the gem is

Stationery writes PDFs from Ruby classes: a document is a class, `view_template` describes it, and the engine measures, places and paginates. It is pure Ruby, with no runtime dependency and no native extension. That is the point of the gem, and no change may give it up.

| Where | What |
|---|---|
| `lib/stationery/` | The gem: elements, layout, text, fonts, images, the PDF writer, tagging, the testing helpers |
| `spec/stationery/`, `spec/integration/` | Unit specs and whole documents; `spec/rails/` runs under `gemfiles/rails.gemfile` |
| `examples/` | One runnable file per example, each with a `preview` |
| `benchmark/` | Benchmarks, the profiler, the memory report and the metrics gate |
| `docs/` | The docs site, a Rails application of its own with its own bundle |

## The canvas

A layout node, the SVG renderer and a `canvas { |c| … }` block call only what `Stationery::Canvas::Interface` names, in top-left coordinates and points: never `canvas.page`, `canvas.num`, a path's `to_s`, an operator or the resources, which are the PDF canvas's own. The paginator, the page templates and `Structure` ask the render's canvases (`PDF::Canvases`) for the canvas of a page, and `Document#paint_on` is what every output runs. `spec/stationery/document_paint_on_spec.rb` paints every example on a canvas that is not the PDF canvas, so a node that reaches for PDF fails there.

## How a change is made

1. **A branch off fresh `main`**, one pull request per issue or per part of one. Nothing is pushed to `main`.
2. **A spec first**, seen failing, then the change.
3. **Before the pull request is opened**, all three pass:

   ```sh
   bundle exec rspec                                  # judged by its exit status, not by its summary line
   bundle exec rubocop lib spec examples Rakefile     # docs/ has its own bundle and is linted by CI
   bundle exec rake metrics
   ```

4. **A changelog bullet** under `## Unreleased` in `CHANGELOG.md`, and the README and docs pages that state what the change touches are updated with it. Several docs pages embed sections of the README, so the README is what counts for them.
5. **Merged when CI is green**, with `main` merged into the branch first when `main` has moved (merged, not rebased).

## The metrics gate

`bundle exec rake metrics` renders fixed documents and compares their allocations, pages and bytes with `benchmark/baseline.json`. CI holds allocations and not time, because wall time on a shared machine is noise.

- **A document that does not use a feature is byte for byte what it was**, and allocates what it did. A new feature costs nothing where it is not used.
- The baseline is recorded again (`bundle exec rake metrics:update`, with the Ruby the baseline names) only for a change made on purpose, and the commit says why.
- A version bump lengthens the version string in the file, so the release preparation records the baseline again.

## What a standard asks for is checked, not reasoned about

| Claim | Validator | Task |
|---|---|---|
| PDF/A, PDF/UA | veraPDF: a local `verapdf` (`brew install verapdf`), else Docker | `bundle exec rake verify:conformance` |
| Factur-X | Mustang, through Docker | `bundle exec rake verify:factur_x` |
| Signatures | `openssl`, and `pdfsig` when installed | `bundle exec rake verify:signature` |
| File structure | `qpdf --check` | by hand |

A new example that is tagged joins the `renders` of `verify:conformance` in the `Rakefile`. A rule is taken from the validator's profile, and a pull request says which rule it is.

## What is drawn is looked at

A change to layout is rendered to a picture (`pdftoppm -png -r 72 file.pdf out`) and looked at before it is merged, and the pull request says what was seen. `to_pdf(debug: true)` draws the rectangles of the layout.

## The changelog

- One bullet per change, under `## Unreleased`, written for someone who uses the gem: what it does, how it is written, what it leaves alone, and the classes it lives in.
- A change in behaviour is named as one. A release gathers them in one bullet, **Behaviour changes**, at the end of its section.
- When both sides of a merge changed a bullet, `main`'s is kept. After a merge the bullets are read again: a union of both sides can keep the wrong copy.

## Releases

Releases are cut by the maintainer with `bin/release` (`bin/release --dry-run` shows what would ship), never with `rake release` by hand and never by an agent without being asked. A release is prepared by a pull request that turns `## Unreleased` into the section of the version and records the metrics baseline.

## Out of scope by design

- A CSS layout engine: `html` reads a subset and reports the rest as `Warnings::UnsupportedCss`.
- Shaping and bidi inside the gem: the `shaper` hook hands text to an application's shaper.
- Native code, and any runtime dependency.
- Lossy WebP.

## Models and agents

**Models.** Sessions run on `opus` (Opus 5.5) with `fable` (Fable 5.1) as the advisor (`.claude/settings.json`). Fable is spent where judgment matters most: `/plan` runs on Fable, the advisor is consulted at decision points (before choosing an approach, a schema or public API, a migration, a dependency, anything irreversible, and when a failure repeats), and the `fable-validator` agent checks every finished implementation before its pull request opens (`/lfg`, Phase 6.5). Commands pin their tier by alias, never by full model ID: `opus` for orchestration, security, full PR review, payments and production debugging; `sonnet` for the implementation specialists and TDD; `haiku` for mechanical scans. Every spawned agent names its `model:`; one that does not runs on `sonnet` (`CLAUDE_CODE_SUBAGENT_MODEL`), never on the session's model. Plan mode cannot take a model of its own: it runs on Opus and asks the advisor.

| Command | Tier | For |
|---|---|---|
| `/plan` | `fable` | A plan as an issue or `docs/plans/*.md`, before `/lfg` |
| `/lfg`, `/architect`, `/finish-prs`, `/github-review-pr`, `/review-pr`, `/security` | `opus` | An issue end to end; work across layers; a queue of pull requests; a full review pass; a review; a security audit |
| `/tdd`, `/perf`, `/github-review-failures`, `/github-review-comments` | `sonnet` | Red, green, refactor; `rake bench` and `rake metrics` against `main`; red CI; review threads |

The commands are in `.claude/commands/`, their shared rules in `.claude/rules/`. The docs site keeps its own: `docs/AGENTS.md` and the `write-docs-page` skill in `docs/.claude/skills/`.

## What has gone wrong before

- Rubocop run on `docs/` from the repository root fails on a missing plugin. Lint `lib spec examples Rakefile` and leave `docs/` to CI.
- The docs image is built from the repository root with `docs/Dockerfile.dockerignore`, which leaves `spec/` out: an example may not read a file from `spec/`.
- Two renders compared byte for byte need the clock pinned, or they differ by their dates when a second turns between them.
- GitHub closes a pull request whose base branch is deleted. A pull request stacked on another is pointed at `main` before its parent is merged.
- An overflow fixture of many paragraphs splits across pages instead of overflowing. Use `box(break_inside: :avoid)` for one that must overflow.
