# frozen_string_literal: true

require_relative "lib/stationery/version"

Gem::Specification.new do |spec|
  spec.name = "stationery"
  spec.version = Stationery::VERSION
  spec.authors = ["Mikael Henriksson"]
  spec.email = ["mikael@mhenrixon.com"]

  spec.summary = "Pure-Ruby, Phlex-style PDF documents: box layout, TrueType fonts, images. No Prawn, no Chrome."
  spec.description = <<~DESC
    Stationery renders PDF documents from Phlex-style Ruby components. Describe
    the page with rows, columns, boxes, tables, text and images; a box-layout
    engine measures, places and paginates them, and a small PDF writer embeds
    subsetted TrueType fonts and JPEG/PNG images. It has no runtime dependencies,
    no native extensions and never starts another process — no Prawn, no
    headless browser.
  DESC
  spec.homepage = "https://github.com/zoolutions/stationery"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.4.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/zoolutions/stationery/tree/main"
  spec.metadata["changelog_uri"] = "https://github.com/zoolutions/stationery/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  # Prefer `git ls-files`, fall back to a glob when the gem is a path/git
  # dependency inside an image without git (Bundler re-evaluates the gemspec on
  # every boot, so a hard git dependency would crash the host app).
  gem_files =
    begin
      tracked = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL, &:read)
      raise "git unavailable" if tracked.nil? || tracked.empty?

      tracked.split("\x0")
    rescue StandardError
      Dir.glob("lib/**/*.rb", base: __dir__) +
        %w[CHANGELOG.md LICENSE.txt README.md].select { |f| File.file?(File.join(__dir__, f)) }
    end

  spec.files = gem_files.select do |f|
    f.start_with?("lib/") || %w[CHANGELOG.md LICENSE.txt README.md].include?(f)
  end
  spec.require_paths = ["lib"]
end
