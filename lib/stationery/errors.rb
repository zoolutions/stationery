# frozen_string_literal: true

module Stationery
  class Error < StandardError; end

  # A font file stationery cannot read or embed (CFF2, collections, WOFF, …).
  class UnsupportedFont < Error; end

  # An image format stationery cannot embed (WebP, GIF, interlaced PNG, …).
  class UnsupportedImage < Error; end

  # Raised by a strict render (`to_pdf(strict: true)`) that produced warnings.
  class WarningsError < Error
    attr_reader :warnings

    def initialize(warnings)
      @warnings = warnings
      lines = warnings.map { |warning| "  #{warning.message}" }
      noun = lines.size == 1 ? "warning" : "warnings"
      super("#{lines.size} #{noun}:\n#{lines.join("\n")}")
    end
  end

  # Raised when a render cannot keep the conformance it claims (PDF/A,
  # PDF/UA): `levels` are the claimed levels, `issues` what breaks them.
  class ConformanceError < Error
    attr_reader :levels, :issues

    def initialize(levels, issues)
      @levels = levels
      @issues = issues
      super("not #{levels.map { |level| Stationery::PDF::Conformance.label(level) }.join(" + ")}:\n" \
            "#{issues.map { |issue| "  #{issue}" }.join("\n")}")
    end
  end
end
