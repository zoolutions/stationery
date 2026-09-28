# frozen_string_literal: true

require "pathname"
require "stringio"
require "stationery"
require_relative "structure_reader"

module Stationery
  module Testing
    # Reads a rendered PDF back for assertions. The subject is a
    # Stationery::Document, PDF bytes, a path (String or Pathname) or an IO.
    # Needs the pdf-reader gem, loaded on first use.
    class Inspector
      UTF16_BOM = "\xFE\xFF".b
      XMP_PROPERTY = %r{^\s*<((?!rdf:)[\w.-]+:[\w.-]+)>(.*?)</\1>$}
      XMP_ITEM = %r{<rdf:li[^>]*>(.*?)</rdf:li>}
      XMP_ENTITIES = { "&amp;" => "&", "&lt;" => "<", "&gt;" => ">", "&quot;" => '"' }.freeze

      def initialize(subject)
        @subject = subject
      end

      def pdf
        @pdf ||= case @subject
                 when Document then @subject.to_pdf
                 when String then @subject.start_with?("%PDF") ? @subject : File.binread(@subject)
                 when Pathname then File.binread(@subject)
                 else @subject.read
                 end
      end

      def reader
        @reader ||= begin
          require "pdf/reader"
          ::PDF::Reader.new(StringIO.new(pdf))
        rescue LoadError
          raise Stationery::Error, 'Stationery::Testing needs pdf-reader: add gem "pdf-reader" to your test group'
        end
      end

      def page_count = reader.page_count
      def page_texts = @page_texts ||= reader.pages.map { |page| page.text.squeeze(" ").strip }
      def text = page_texts.join("\n")
      def metadata = reader.info

      # The XMP packet (the catalog's /Metadata stream) as a String, or nil.
      def xmp
        return unless catalog[:Metadata]

        objects.deref!(catalog[:Metadata]).unfiltered_data.dup.force_encoding(Encoding::UTF_8)
      end

      # The packet's properties by prefixed name (`"dc:title"`): a plain value
      # as a String, an rdf:Alt as its default String, an rdf:Seq or rdf:Bag as
      # an Array. Reads the packets Stationery writes (one property per line).
      def xmp_values
        packet = xmp
        return {} unless packet

        packet.scan(XMP_PROPERTY).to_h { |name, body| [name, xmp_value(body)] }
      end

      # The conformance levels the XMP packet claims, as PDF::Conformance
      # names them: `[:pdf_a3b, :pdf_ua1]`, or [] without a claim.
      def conformance
        values = xmp_values
        part, level, accessible = values.values_at("pdfaid:part", "pdfaid:conformance", "pdfuaid:part")
        [part && :"pdf_a#{part}#{level.to_s.downcase}", accessible && :"pdf_ua#{accessible}"].compact
      end

      def image_count = pdf.scan(%r{/Subtype\s*/Image\b}).size

      def warnings
        return [] unless @subject.is_a?(Document)

        pdf
        @subject.warnings.to_a
      end

      def links
        annotations.filter_map { |annot| annot.dig(:A, :URI) if annot.dig(:A, :S) == :URI }
      end

      def internal_links
        annotations.filter_map do |annot|
          dest = annot[:Dest] || (annot.dig(:A, :D) if annot.dig(:A, :S) == :GoTo)
          destination(dest) if dest
        end
      end

      def bookmarks
        outlines = catalog[:Outlines]
        outlines ? titles(outlines[:First]) : []
      end

      # The catalog /Lang written by `metadata lang:`, or nil.
      def lang
        lang = catalog[:Lang]
        decode(lang) if lang
      end

      # One label per page from the catalog /PageLabels ("i", "A-1", …), nil
      # for pages before the first labelled range; empty without labels.
      def page_labels
        labels = catalog[:PageLabels]
        return [] unless labels

        nums = objects.deref_array(objects.deref_hash(labels)[:Nums]).map { |value| objects.deref(value) }
        nums = nums.map { |value| value.is_a?(Hash) ? value.transform_values { |v| decode_value(v) } : value }
        PDF::PageLabels.labels(nums, page_count)
      end

      # Every embedded file from the catalog's /EmbeddedFiles name tree:
      # `{ name:, mime:, bytes:, description:, relationship: }` (bytes inflated).
      def attachments
        names = catalog.dig(:Names, :EmbeddedFiles)
        return [] unless names

        entries = objects.deref_array(objects.deref_hash(names)[:Names])
        entries.each_slice(2).map { |_name, ref| attachment(objects.deref_hash(ref)) }
      end

      # The structure tree of a tagged PDF as nested arrays; see StructureReader.
      def structure = @structure ||= StructureReader.new(reader).tree

      # Whether the catalog marks the PDF as tagged and holds a structure tree.
      def tagged?
        catalog.dig(:MarkInfo, :Marked) == true && !catalog[:StructTreeRoot].nil?
      end

      # Text shown outside any marked content (neither tagged nor an artifact).
      def untagged_text
        @untagged_text ||= reader.pages.flat_map { |page| MarkedText.read(page).unmarked }
      end

      private

      def objects = reader.objects
      def catalog = objects.deref!(objects.trailer[:Root])

      def annotations
        reader.pages.flat_map do |page|
          Array(objects.deref_array(page.attributes[:Annots])).map do |ref|
            annot = objects.deref_hash(ref)
            annot.merge(A: objects.deref_hash(annot[:A]))
          end
        end
      end

      def attachment(spec)
        stream = objects.deref(objects.deref_hash(spec[:EF])[:F])
        relationship = PDF::Attachments::RELATIONSHIPS.key(spec[:AFRelationship]) || spec[:AFRelationship]
        { name: decode(spec[:UF] || spec[:F]), mime: stream.hash[:Subtype].to_s, bytes: stream.unfiltered_data,
          description: spec[:Desc] && decode(spec[:Desc]), relationship: }
      end

      def xmp_value(body)
        items = body.scan(XMP_ITEM).flatten.map { |item| xmp_text(item) }
        return xmp_text(body) if items.empty?

        body.start_with?("<rdf:Alt>") ? items.first : items
      end

      def xmp_text(value) = value.gsub(/&(amp|lt|gt|quot);/, XMP_ENTITIES)

      def destination(dest)
        return dest.to_s unless dest.is_a?(Array)

        objects.page_references.index(dest.first) + 1
      end

      def titles(item)
        return [] unless item

        [decode(item[:Title]), *titles(item[:First]), *titles(item[:Next])]
      end

      def decode_value(value) = value.is_a?(String) ? decode(value) : value

      def decode(title)
        return title.dup.force_encoding(Encoding::UTF_8) unless title.b.start_with?(UTF16_BOM)

        title.b.byteslice(2..).force_encoding(Encoding::UTF_16BE).encode(Encoding::UTF_8)
      end
    end
  end
end
