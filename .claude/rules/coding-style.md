# Coding style

- Pure Ruby, stdlib only: no runtime dependency, no native extension. That is the point of the gem.
- Many small files: 200 to 400 lines typical, 800 at most; methods short; nesting shallow. Organised by concern, as `lib/stationery/` is (`text/`, `layout/`, `pdf/`, `raster/`, …).
- A layout node, the SVG renderer and a `canvas` block call only what `Stationery::Canvas::Interface` names, in top-left coordinates and points.
- A feature costs nothing where it is not used: no allocation, no byte of output.
- What the gem cannot do is reported as a warning (`Warnings::…`), not approximated and not raised where a document can still render.
- No `rescue` that swallows, no `&.` over a nil you have not explained.
- Thread safety: no shared mutable state at class level (`rubocop-thread_safety` holds it).
- `bundle exec rubocop lib spec examples Rakefile` passes; `docs/` has its own bundle and is linted by CI.
