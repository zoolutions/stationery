# frozen_string_literal: true

require "tmpdir"
require "fileutils"
require "stationery/minitest"

# What spec/stationery/skill_spec.rb holds the skill's hand-written parts
# (SKILL.md and the recipes) to: the methods they name exist, and the
# documents they write render.
module SkillChecks
  WRITTEN = %r{\A(SKILL\.md|recipes/)}
  ASSETS = File.expand_path("../../examples/assets", __dir__)

  # Inline code that starts with a method name, `name(`, `name args` or
  # `receiver.name`, names one the gem has.
  class Names
    # Words in code that are not the gem's: shell commands, keywords, the
    # docs server's MCP tools and the names of block arguments.
    NOT_METHODS = %w[stationery ruby bundle gem docker claude mutool pdftoppm verapdf zbarimg brew grep
                     true false nil def rect value
                     search_docs get_page list_pages].freeze

    def initialize(files)
      @text = files.select { |path, _| path.match?(WRITTEN) }.values.join("\n").gsub(/^```.*?^```/m, "")
    end

    def unknown = (named - known - NOT_METHODS - Stationery::Examples.names).sort

    def named
      @text.scan(/(?<!`)`([^`\n]+)`/).flatten.filter_map do |span|
        next if span.match?(%r{\A[A-Z:$"'-]|/|::|#})

        span[/\A(?:[a-z_]\w*\.)*([a-z_][a-z0-9_]*[?!]?)(?=[\s(]|\z)/, 1]
      end.uniq
    end

    # stationery/rails is required here, not when the suite loads: spec/rails
    # requires it after Rails, for the Railtie.
    def known
      require "stationery/rails"
      [Stationery::Document, Stationery::Canvas, Stationery::Layout::Table, Stationery::Layout::Table::Selection,
       Stationery::Testing::Inspector, Stationery::PageInfo, Stationery::Rails,
       Stationery::Warnings::MissingGlyph, String].flat_map do |klass|
        klass.public_instance_methods + klass.private_instance_methods
      end.concat(Stationery::Document.singleton_class.public_instance_methods,
                 Stationery::Testing::Matchers.instance_methods,
                 Stationery::Testing::Assertions.instance_methods).map(&:to_s).uniq
    end
  end

  # The documents the recipes write, built from their `self.preview` in a
  # directory that holds the pictures they read (logo.png, photos/).
  class Recipes
    module Built; end

    def initialize(files)
      @files = files.select { |path, _| path.start_with?("recipes/") }
    end

    def documents
      dir = Dir.mktmpdir("recipes")
      FileUtils.cp(File.join(ASSETS, "logo.png"), dir)
      FileUtils.cp_r(ASSETS, File.join(dir, "photos"))
      @files.flat_map { |path, text| build(path, text, dir) }
    end

    private

    def build(path, text, dir)
      text.scan(/^```ruby\n(.*?)^```/m).flatten.filter_map do |code|
        source = code[/^class (\w+) < Stationery::Document\n.*?^end$/m] or next
        name = source[/\Aclass (\w+)/, 1]
        # Named, as `stationery render` asks of a document class, and anew each time.
        namespace = Built.const_set("#{name}#{Built.constants.size}", Module.new)
        namespace.module_eval(source, File.join(dir, "#{File.basename(path, ".md")}.rb"), 1)
        ["#{path} #{name}", namespace.const_get(name).preview]
      end
    end
  end
end
