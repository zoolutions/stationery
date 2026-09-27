# stationery docs

The documentation site for the `stationery` gem, served at
https://stationery.zoolutions.llc. It is a [docs-kit](https://docs-kit.zoolutions.llc)
Rails app and is not part of the gem (the gemspec ships only `lib/` and `exe/`).

```sh
cd docs
bundle install
bun install && bun run build:css
bin/dev                       # http://localhost:3000
bundle exec rspec             # every page, its .md twin, llms.txt
bundle exec rubocop
```

- Pages: `app/views/docs/pages/*.rb`, registered in `app/models/doc.rb`
  (`bin/rails g docs_kit:page "Title" --group=Guide` does both).
- Several pages render the repo's `README.md`, `CHANGELOG.md` and `examples/`
  through `SourceMarkdown`, so those stay the single source; renaming a README
  heading a page reads fails the docs specs.
- Deploy: `.github/workflows/deploy-docs.yml` (a GitHub release or a manual
  run). The image builds from the repo root with `docs/Dockerfile`.
