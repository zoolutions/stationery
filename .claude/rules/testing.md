# Testing

- A spec first, seen failing, then the change (`/tdd`).
- `bundle exec rspec` is judged by its exit status, not by its summary line.
- Unit specs in `spec/stationery/`, whole documents in `spec/integration/`, Rails in `spec/rails/` (`BUNDLE_GEMFILE=gemfiles/rails.gemfile bundle exec rake spec:rails`).
- Assert through the testing helpers (`lib/stationery/testing/`) on what was laid out and drawn, not on a whole PDF's bytes.
- Byte-for-byte comparisons pin the clock.
- An overflow fixture uses `box(break_inside: :avoid)`.
- An example reads nothing from `spec/`; every example has a `preview` and is painted on a non-PDF canvas by `spec/stationery/document_paint_on_spec.rb`.
- What a standard asks for is checked by its validator, not by a spec that reasons about it: `rake verify:conformance` (veraPDF), `verify:factur_x` (Mustang), `verify:signature` (openssl, pdfsig). A new tagged example joins `verify:conformance`'s `renders`.
- What is drawn is looked at: `bundle exec stationery render <file>.rb --png`, and open the PNGs.
- Coverage: 80% at least; every branch of a public DSL option.
