# frozen_string_literal: true

# Reads the gem's own Markdown (README.md, CHANGELOG.md, examples/) from the
# repo root, so pages that restate them stay in sync with one source. The docs
# app lives in docs/ and the Docker build context is the repo root, so the
# files are always one directory up.
module SourceMarkdown
  ROOT = Pathname.new(File.expand_path("../../..", __dir__))

  module_function

  # The body of a README section: everything under `## heading` (or `### …`)
  # up to the next heading of the same or a shallower level, heading excluded.
  def readme_section(heading)
    lines = read("README.md").lines
    start = lines.index { |line| line.match?(/\A(#+) #{Regexp.escape(heading)}\s*\z/) }
    raise KeyError, "README.md has no section #{heading.inspect}" unless start

    level = lines[start][/\A#+/].size
    body = lines[(start + 1)..].take_while do |line|
      !(line.match?(/\A#+ /) && line[/\A#+/].size <= level)
    end
    body.join.strip
  end

  # CHANGELOG.md without its title line.
  def changelog = read("CHANGELOG.md").sub(/\A# Changelog\s*/, "").strip

  # The comment block at the top of an example, as prose.
  def example_summary(name)
    read("examples/#{name}").lines.drop(2).take_while { |line| line.start_with?("#") && !line.match?(/\A#\s*\z/) }
                            .map { |line| line.delete_prefix("#").strip }.join(" ").sub(/\s*Run it.*\z/, "")
  end

  # An example as it is written, from its first line to its last.
  def example_source(name) = read("examples/#{name}")

  # The class-level configuration of an example: from its `page` line up to
  # the first `def`, dedented, so the excerpt follows the file as it changes.
  def example_config(name)
    lines = read("examples/#{name}").lines
    start = lines.index { |line| line.start_with?("  page ") } or raise KeyError, "#{name} has no page line"
    lines[start..].take_while { |line| !line.start_with?("  def ") }.map { |line| line.delete_prefix("  ") }.join.rstrip + "\n"
  end

  # One method of an example, `def` to its closing `end`, dedented.
  def example_method(name, method)
    lines = read("examples/#{name}").lines
    start = lines.index { |line| line.match?(/\A(\s*)def #{Regexp.escape(method)}\b/) }
    raise KeyError, "#{name} has no method #{method}" unless start

    indent = lines[start][/\A\s*/]
    stop = start + lines[start..].index { |line| line.rstrip == "#{indent}end" }
    lines[start..stop].map { |line| line.delete_prefix(indent) }.join
  end

  def read(path) = ROOT.join(path).read(encoding: "UTF-8")
end
