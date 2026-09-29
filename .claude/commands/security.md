---
description: "Reviews code for security vulnerabilities. Use when auditing input parsing (fonts, images, SVG, HTML, Markdown), file access, signatures and encryption, embedded files, or the CLI."
model: opus
argument-hint: "code, feature, or area to review for security"
---

# Security review

Stationery reads input an application may take from its users (text, HTML, Markdown, SVG, images, fonts, attachments) and writes PDFs that others open. Audit the change for what hostile input can do.

## Where to look

- **Parsers of untrusted bytes**: TrueType/OpenType (`fonts/`), PNG, JPEG, WebP (`images/`), SVG (`svg/`), `html/`, `css/`, `markdown/`. Look for unbounded loops and recursion, sizes and offsets read from the file and trusted (huge allocations, reads past the end), decompression bombs (zlib), integer overflow in dimensions.
- **File access**: a path taken from the document (an image `src`, a font, an attachment, an HTML `<img>`) must not reach files the application did not intend; no network fetch where none was asked for.
- **Code execution**: no `eval`, `instance_eval` of strings, `Marshal.load`, `YAML.load` (use `safe_load`), `send` with a name from input, shell with interpolation (`Open3` with an argument array; the Rake tasks included).
- **PDF output**: strings and names escaped as PDF syntax (a `)` or `\` in text, a `/` in a name); JavaScript, launch actions and URIs in annotations only as the document asked; link targets not taken blindly from HTML.
- **Signatures and encryption** (`pdf/signature/`, `pdf/encryption/`): the byte range covers everything but the signature; keys and passwords never logged or left in the output; cipher choices as the standard says; `rake verify:signature` passes.
- **Embedded files** (Factur-X, attachments): names and MIME types sanitised.
- **CLI** (`cli/`): `stationery render` loads Ruby, which is by design; it must not do more than it says (no writes outside `--out`).
- **Dependencies**: none at runtime is a security property; a change that adds one is refused.

## Checks

```bash
bundle exec rspec
bundle exec rubocop lib spec examples Rakefile
grep -rn "eval\|Marshal\|YAML.load\|system(\|%x\|\`" lib/
bundle exec rake verify:signature     # when signatures are touched
```

## Report

Each finding with severity, `file:line`, the input that triggers it, the fix, and the spec that should prove it.
