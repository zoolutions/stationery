# frozen_string_literal: true

require "stationery"
require "stationery/testing/inspector"
require_relative "verify/command"
require_relative "verify/engine"
require_relative "verify/engines/qpdf"
require_relative "verify/engines/poppler"
require_relative "verify/engines/mupdf"
require_relative "verify/engines/pdfium"
require_relative "verify/engines/pdfjs"
require_relative "verify/engines/pdfkit"
require_relative "verify/allowlist"
require_relative "verify/expectation"
require_relative "verify/comparison"
require_relative "verify/report"

module Stationery
  # Checks PDFs in the engines viewers are built on: qpdf, Poppler (the
  # Linux desktop viewers), MuPDF, PDFium (Chrome, Edge), pdf.js (Firefox)
  # and PDFKit (Preview, Safari). Each engine is an external tool the check
  # finds when it is installed; the gem depends on none of them. What the
  # engines read is held against what pdf-reader reads (Expectation), so
  # `stationery verify` needs pdf-reader, as `inspect` does.
  #
  # `require "stationery"` does not load this: `stationery verify` and
  # `rake verify:readers` do.
  #
  # An engine's facts about a file are a Hash, as its script prints them in
  # JSON: `"file"`, `"errors"`, `"warnings"`, `"pages"` (each `"number"`,
  # `"text"`, `"painted"`, `"links"`, a link `{"uri"}` or `{"page"}`), and
  # `"outline"` (titles in order), `"fields"` (`"name"`, `"value"`,
  # `"appearance"`), `"attachments"` (names), `"signatures"` (`"count"`,
  # `"valid"`), `"structure"` and `"fonts"` (`"name"`, `"embedded"`,
  # `"unicode"`). A fact an engine does not report is nil or left out, and
  # is not checked.
  module Verify
    ENGINES = { "qpdf" => Engines::Qpdf, "poppler" => Engines::Poppler, "mupdf" => Engines::Mupdf,
                "pdfium" => Engines::Pdfium, "pdfjs" => Engines::Pdfjs, "pdfkit" => Engines::Pdfkit }.freeze

    # One adapter for each engine, or for each of `names`; raises
    # ArgumentError for a name that is not an engine.
    def self.adapters(names = ENGINES.keys)
      names.map do |name|
        ENGINES.fetch(name.to_s) { raise ArgumentError, "no engine #{name} (engines: #{ENGINES.keys.join(", ")})" }.new
      end
    end

    # Reads each of `paths` with each of `engines` that is available and
    # holds what it read against the file: a Report. `password` opens
    # encrypted files.
    def self.run(paths, engines: adapters, password: nil)
      require_reader
      available, missing = engines.partition(&:available?)
      expectations = paths.to_h { |path| [path, expectation(path, password)] }
      # Absolute, so no path reaches a tool as an option ("-o…").
      absolute = paths.map { |path| File.expand_path(path) }
      results = available.flat_map do |engine|
        version = engine.version
        engine.facts(absolute, password:).zip(paths).map do |facts, path|
          Report::Result.new(file: path, engine: engine.name, version:,
                             problems: problems(expectations[path], facts, engine))
        end
      end
      Report.new(results: results.sort_by.with_index { |result, index| [paths.index(result.file), index] }, missing:)
    end

    def self.require_reader
      require "pdf/reader"
    rescue LoadError
      raise Stationery::Error, Testing::Inspector::NEEDS_READER
    end

    def self.expectation(path, password)
      Expectation.read(Testing::Inspector.new(Pathname(path), password:))
    rescue StandardError => e
      e # pdf-reader cannot read it: each engine is then held to opening it with no error, and the file fails
    end

    def self.problems(expectation, facts, engine)
      return Comparison.new(expectation, facts, engine: engine.name).problems if expectation.is_a?(Expectation)

      ["pdf-reader cannot read the file (#{expectation.class.name.split("::").last}: #{expectation.message}), " \
       "so there is nothing to hold the engine to",
       *Comparison.new(Expectation.new(pages: [], outline: [], fields: [], attachments: [], signatures: 0, valid: true,
                                       tagged: false), facts.slice("errors", "warnings"), engine: engine.name).problems]
    end
  end
end
