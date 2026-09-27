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
end
