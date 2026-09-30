# frozen_string_literal: true

module Stationery
  module Verify
    # Holds one engine's facts about a file (see Verify) against the
    # Expectation and answers the problems, as lines a person reads. A fact
    # the engine does not report (nil) is not held to anything; one it does
    # report is held to the expectation.
    #
    # Text is "found", not "equal": both sides are normalized the same way
    # (NFKC, no whitespace, no soft hyphens), then each of the expectation's
    # lines for a page must appear in the engine's text for that page. Every
    # error and warning is a problem unless the allowlist names it.
    class Comparison
      IGNORED = /[[:space:]\u00AD]/
      SHOWN = 5 # text lines not found named on a page; the rest are counted
      BARE_ORIGIN = %r{\A(https?://[^/?#]+)\z}i

      def initialize(expectation, facts, engine:, allowlist: Allowlist::ENTRIES)
        @expectation = expectation
        @facts = facts
        @engine = engine.to_s
        @allowlist = allowlist
      end

      def problems
        [*messages("errors", "error"), *messages("warnings", "warning"), *page_count, *pages, *fonts, *fields,
         *listed("outline", @expectation.outline, ordered: true),
         *listed("attachments", @expectation.attachments, ordered: false),
         *signatures, *structure]
      end

      private

      def messages(key, label)
        Array(@facts[key]).uniq.reject { |message| Allowlist.allows?(@allowlist, @engine, message) }
                          .map { |message| "#{label}: #{message}" }
      end

      def read_pages = Array(@facts["pages"])

      def page_count
        count = read_pages.size
        expected = @expectation.pages.size
        count == expected ? [] : ["#{count} pages, expected #{expected}"]
      end

      def pages
        @expectation.pages.zip(read_pages).flat_map do |expected, read|
          next [] unless read

          [*text(expected, read["text"]), *painted(expected, read["painted"]), *links(expected, read["links"])]
            .map { |problem| "page #{expected.number}: #{problem}" }
        end
      end

      def text(expected, text)
        return [] if text.nil?

        found = normalize(text)
        missing = expected.lines.reject { |line| found?(found, line) }
        more = missing.size > SHOWN ? ["text not found: #{missing.size - SHOWN} more lines"] : []
        missing.first(SHOWN).map { |line| "text not found: #{line.inspect}" } + more
      end

      # A line is found whole, or in two pieces split at a space: a run of
      # text can join what the page draws apart (a list's marker and its
      # item), which an engine may read in another order (PDFKit on macOS 26).
      def found?(found, line)
        whole?(found, normalize(line)) || pieces(line).any? { |parts| parts.all? { |part| whole?(found, part) } }
      end

      # A line that ends in a hyphen is found without it too: an engine may
      # join a word broken across lines (pdftotext does).
      def whole?(found, line) = found.include?(line) || (line.end_with?("-") && found.include?(line.chomp("-")))

      def pieces(line)
        line.enum_for(:scan, /[[:space:]]+/).map { Regexp.last_match }
            .map { |gap| [line[0...gap.begin(0)], line[gap.end(0)..]].map { |part| normalize(part) } }
            .reject { |parts| parts.any?(&:empty?) }
      end

      def normalize(text) = text.unicode_normalize(:nfkc).gsub(IGNORED, "")

      def painted(expected, painted)
        painted == false && expected.content ? ["painted blank, but it has content"] : []
      end

      def links(expected, links)
        return [] if links.nil?

        read = links.map { |link| target(link.transform_keys(&:to_sym)) }
        count = read.size == expected.links.size ? [] : ["#{read.size} links, expected #{expected.links.size}"]
        missing = expected.links.reject(&:empty?).reject do |link|
          index = read.index(target(link))
          read.delete_at(index) if index
        end
        count + missing.map { |link| "link not found: #{link.inspect}" }
      end

      # A web address with no path is the same with the "/" pdf.js adds.
      def target(link) = link[:uri] ? { uri: link[:uri].sub(BARE_ORIGIN, '\\1/') } : link

      def fonts
        Array(@facts["fonts"]).flat_map do |font|
          [("font #{font["name"]} is not embedded" if font["embedded"] == false),
           ("font #{font["name"]} has no ToUnicode" if font["unicode"] == false)].compact
        end
      end

      def fields
        read = @facts["fields"]
        return [] if read.nil?

        @expectation.fields.flat_map do |field|
          widgets = read.select { |widget| widget["name"] == field[:name] }
          next ["field #{field[:name]} not found"] if widgets.empty?

          [*value(field, widgets), *appearance(field, widgets)]
        end
      end

      def appearance(field, widgets)
        return [] unless field[:visible] && widgets.any? { |widget| widget["appearance"] == false }

        ["field #{field[:name]} has no appearance"]
      end

      def value(field, widgets)
        return [] unless field[:type] == :text && field[:value].is_a?(String)

        values = widgets.filter_map { |widget| widget["value"] }
        values.reject { it == field[:value] }.first(1).map do |value|
          "field #{field[:name]} holds #{value.inspect}, expected #{field[:value].inspect}"
        end
      end

      def listed(key, expected, ordered:)
        read = @facts[key]
        return [] if read.nil? || (ordered ? read == expected : read.sort == expected.sort)

        ["#{key} #{read.inspect}, expected #{expected.inspect}"]
      end

      def signatures
        read = @facts["signatures"]
        return [] if read.nil?

        expected = @expectation.signatures
        count = read["count"] == expected ? [] : ["#{read["count"]} signatures, expected #{expected}"]
        count + (read["valid"] == false ? ["a signature does not verify"] : [])
      end

      def structure
        @facts["structure"] == false && @expectation.tagged ? ["no structure tree, but the file is tagged"] : []
      end
    end
  end
end
