# frozen_string_literal: true

module Stationery
  module PDF
    # The archival and accessibility standards a render claims, and what each
    # asks of the file: PDF/A-2b and PDF/A-3b (ISO 19005-2/3, level B) and
    # PDF/UA-1 (ISO 14289-1). Levels combine: `Conformance.new(:pdf_a3b, :pdf_ua1)`.
    #
    # A claim is only written when the document keeps it: what cannot be made
    # conformant raises (ArgumentError for options that contradict the level,
    # ConformanceError for content), so a file is never mislabelled.
    class Conformance
      LEVELS = {
        pdf_a2b: { standard: :pdf_a, part: 2, conformance: "B", label: "PDF/A-2b" },
        pdf_a3b: { standard: :pdf_a, part: 3, conformance: "B", label: "PDF/A-3b" },
        pdf_ua1: { standard: :pdf_ua, part: 1, label: "PDF/UA-1" }
      }.freeze
      PDFA_ID = "http://www.aiim.org/pdfa/ns/id/"
      PDFUA_ID = "http://www.aiim.org/pdfua/ns/id/"
      # PDF/A knows its own schema; PDF/UA's has to be described to it.
      PDFUA_SCHEMA = {
        name: "PDF/UA identification schema", uri: PDFUA_ID, prefix: "pdfuaid",
        properties: [{ name: "part", type: "Integer", category: "internal",
                       description: "The part of ISO 14289 the document conforms to" }]
      }.freeze
      ICC_PROFILE = File.expand_path("icc/sRGB2014.icc", __dir__)
      OUTPUT_CONDITION = "sRGB IEC61966-2.1"
      PRINT = 4
      CMYK_OPERATOR = /^(?:-?[\d.]+ ){4}[kK]$/

      attr_reader :levels

      def self.label(level) = LEVELS.dig(level.to_sym, :label) || level.to_s

      # The Conformance for `levels` (a Symbol, an Array or nil); nil without any.
      def self.for(levels)
        levels = Array(levels).flatten.compact
        levels.empty? ? nil : new(*levels)
      end

      def initialize(*levels)
        @levels = levels.flatten.map(&:to_sym).uniq
        unknown = @levels - LEVELS.keys
        raise ArgumentError, "unknown conformance #{unknown.map(&:inspect).join(", ")} (use #{names})" if unknown.any?
        raise ArgumentError, "conformance takes one PDF/A level, got #{archival.join(" and ")}" if archival.size > 1
      end

      def pdf_a? = archival.any?
      def pdf_ua? = @levels.include?(:pdf_ua1)
      # The PDF/A part (2 or 3), nil without one.
      def part = archival.first && LEVELS.dig(archival.first, :part)

      # What can be refused before anything is drawn: options and metadata.
      def validate!(encrypt:, metadata:, attachments:)
        raise ArgumentError, "PDF/A forbids encryption: drop encrypt: or the conformance level" if pdf_a? && encrypt
        if part == 2 && attachments.any?
          raise ArgumentError, "PDF/A-2b only embeds PDF/A files: use conformance :pdf_a3b to attach " \
                               "#{attachments.map(&:name).join(", ")}"
        end

        missing = pdf_ua? ? %i[title lang].select { |key| metadata[key].to_s.strip.empty? } : []
        raise ConformanceError.new(@levels, missing.map { |key| "metadata #{key}: is missing" }) if missing.any?
      end

      # What only the finished pages show. Colour that the sRGB output intent
      # does not cover is reported; what breaks the claim outright raises.
      def audit!(pages, resources:, warnings:)
        cmyk(pages, resources).each { |subject| warnings << Warnings::ConformanceIssue.new(level: archival.first, subject:) }
        issues = fields(pages) + alternatives(warnings)
        raise ConformanceError.new(@levels, issues) if issues.any?
      end

      # The identification schemas for the XMP packet (see XMP.packet).
      def xmp_extensions
        extensions = {}
        extensions[PDFA_ID] = { prefix: "pdfaid", "part" => part, "conformance" => "B" } if pdf_a?
        extensions[PDFUA_ID] = { prefix: "pdfuaid", "part" => 1 } if pdf_ua?
        extensions
      end

      # Schemas PDF/A has to be told about: PDF/UA's, when both are claimed.
      def xmp_schemas = pdf_a? && pdf_ua? ? [PDFUA_SCHEMA] : []

      # The catalog's entries: the sRGB output intent of a PDF/A file.
      def catalog_entries(writer)
        return {} unless pdf_a?

        profile = writer.add(Stream.new(File.binread(ICC_PROFILE), { N: 3 }))
        { OutputIntents: [{ Type: :OutputIntent, S: :GTS_PDFA1, DestOutputProfile: profile,
                            OutputConditionIdentifier: TextString.new(OUTPUT_CONDITION),
                            Info: TextString.new(OUTPUT_CONDITION) }] }
      end

      # A page's entries: PDF/UA tabs through annotations in structure order.
      # `annotated` is whether the page has any, its own or a signature's.
      def page_entries(page, annotated: page.annotations.any?) = pdf_ua? && annotated ? { Tabs: :S } : {}

      # A link annotation's entries: printable, and described for PDF/UA.
      def annotation_entries(link)
        entries = { F: PRINT }
        entries[:Contents] = TextString.new(description(link)) if pdf_ua?
        entries
      end

      private

      def archival = @levels.select { |level| LEVELS.dig(level, :standard) == :pdf_a }
      def names = LEVELS.keys.map(&:inspect).join(", ")

      def description(link)
        link[:url] || "Page #{link[:dest].page + 1}"
      end

      # A form field draws with the document's embedded fonts; one made
      # without a font book draws with the standard Helvetica, which is not
      # embedded: neither PDF/A nor PDF/UA accepts that.
      def fields(pages)
        widgets = pages.flat_map(&:annotations).select { |annotation| annotation[:widget] }
        names = widgets.reject { |annotation| annotation[:appearance].embedded? }.map { |a| a[:widget].name }.uniq
        names.map { |name| %(form field "#{name}" draws with a font that is not embedded) }
      end

      def alternatives(warnings)
        return [] unless pdf_ua?

        warnings.grep(Warnings::MissingAlt).map(&:message)
      end

      def cmyk(pages, resources)
        return [] unless pdf_a?

        images = resources.images.any? { |image| image.respond_to?(:color_space) && image.color_space == :DeviceCMYK }
        subjects = images ? ["a CMYK image"] : []
        pages.each_with_index do |page, index|
          subjects << "CMYK colour on page #{index + 1}" if page.content.match?(CMYK_OPERATOR)
        end
        subjects
      end
    end
  end
end
