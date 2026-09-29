# frozen_string_literal: true

require "erb"
require "stationery"
require_relative "examples"

module Stationery
  # The skill for coding agents that ships with the gem: a SKILL.md and the
  # reference and recipe files beside it, written from the templates under
  # lib/stationery/skill/ and the sections of the README they embed, so it
  # says what the README says. `stationery skill install` writes it where an
  # agent finds it (see Skill::Targets).
  #
  #   Stationery::Skill.new.files # => { "SKILL.md" => "---\nname: stationery…", "reference/elements.md" => … }
  class Skill
    NAME = "stationery"
    GENERATOR = "stationery skill"
    TEMPLATES = File.expand_path("skill", __dir__)
    ROOT = File.expand_path("../..", __dir__)
    DOCS = "https://stationery.zoolutions.llc"

    # The version a SKILL.md was written for, when stationery wrote it.
    def self.version_of(text)
      matter = text[/\A---\n(.*?)\n---\n/m, 1].to_s
      return unless matter.match?(/^\s+generator: #{GENERATOR}$/o)

      matter[/^\s+version: "?([^"\s]+)"?$/, 1]
    end

    def initialize(readme: nil)
      @readme = readme
    end

    # Every file of the skill by its path in the skill's directory, SKILL.md
    # first.
    def files
      @files ||= templates.to_h { |path| [path.delete_suffix(".erb"), render(path)] }
    end

    private

    def templates
      paths = Dir.glob("**/*.md.erb", base: TEMPLATES).sort
      ["SKILL.md.erb", *(paths - ["SKILL.md.erb"])]
    end

    def render(path)
      context = Context.new(readme).instance_eval { binding }
      ERB.new(File.read(File.join(TEMPLATES, path)), trim_mode: "-").result(context)
    end

    def readme = @readme ||= File.read(File.join(ROOT, "README.md"), encoding: "UTF-8")

    # What a template calls: the README's sections, the version, the docs
    # site's pages and the examples' summaries.
    class Context
      def initialize(readme)
        @readme = readme
      end

      def version = VERSION
      def docs(slug, anchor = nil) = [DOCS, "/docs/", slug, ("##{anchor}" if anchor)].join

      # The body of a README section: everything under `## heading` (or
      # `### …`) to the next heading of its level or a shallower one, without
      # its subsections when `subsections: false`. A `#` inside a fenced code
      # block is a comment, not a heading. Links to the README's own anchors
      # keep their text only.
      def readme(heading, subsections: true)
        headings = self.headings
        start = headings.index { |_, _, title| title == heading }
        raise KeyError, "README.md has no section #{heading.inspect}" unless start

        line, level, = headings[start]
        stop = headings[(start + 1)..].find { |_, other, _| !subsections || other <= level }
        body = @readme.lines[(line + 1)...(stop ? stop[0] : @readme.lines.size)]
        body.join.strip.gsub(/\[([^\]]+)\]\(#[^)]*\)/, '\1')
      end

      # [line index, level, title] of every heading outside code blocks.
      def headings
        fenced = false
        @readme.lines.each_with_index.filter_map do |line, index|
          fenced = !fenced if line.lstrip.start_with?("```")
          next if fenced || !line.match?(/\A#+ \S/)

          [index, line[/\A#+/].size, line.sub(/\A#+ /, "").strip]
        end
      end

      def example?(name) = Examples.names.include?(name)

      # What an example shows: the first sentence of its header comment.
      def example(name)
        raise KeyError, "no example named #{name.inspect}" unless example?(name)

        Examples.summary(name)
      end
    end
  end
end
