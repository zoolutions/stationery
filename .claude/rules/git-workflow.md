# Git workflow

- A branch off fresh `main` (`git fetch origin main`, `git switch -c <type>/<slug> origin/main`), one pull request per issue or part of one. Nothing is pushed to `main`.
- Conventional commits: `feat:`, `fix:`, `perf:`, `refactor:`, `docs:`, `test:`, `chore:`, `ci:`; the body says why; `Refs #n` / `Closes #n`. No AI attribution.
- Label the PR: exactly one `type` + at least one `area` (`gh pr create --label ...`), never a `status` label. `bin/labels infer <changed paths>` gives the areas; the taxonomy is `.github/labels.yml`, the rules are `.github/LABELS.md`.
- Before the pull request opens: `bundle exec rspec` (exit status), `bundle exec rubocop lib spec examples Rakefile`, `bundle exec rake metrics`; a changelog bullet under `## Unreleased`; README and docs pages updated.
- When `main` moves, merge it into the branch; never rebase a branch with a pull request, never force-push.
- A pull request stacked on another is pointed at `main` before its parent merges: GitHub closes a pull request whose base branch is deleted.
- Merged when CI is green.
- Labels are edited in `.github/labels.yml` and applied with `bin/labels sync`, never by hand in the GitHub UI. `bin/labels` and `.github/LABELS.md` are the zoolutions labels kit (canonical copy in docs-kit, see its LABELS_KIT.md): never edit them here; change docs-kit, then `script/labels-kit sync`.
- Releases are the maintainer's, with `bin/release`. Never `rake release`, never by an agent unasked.
