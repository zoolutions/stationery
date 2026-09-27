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
        outlines = objects.deref!(objects.trailer[:Root])[:Outlines]
        outlines ? titles(outlines[:First]) : []
      end

      # The structure tree of a tagged PDF as nested arrays; see StructureReader.
      def structure = @structure ||= StructureReader.new(reader).tree

      # Whether the catalog marks the PDF as tagged and holds a structure tree.
      def tagged?
        catalog = objects.deref!(objects.trailer[:Root])
        catalog.dig(:MarkInfo, :Marked) == true && !catalog[:StructTreeRoot].nil?
      end

      # Text shown outside any marked content (neither tagged nor an artifact).
      def untagged_text
        @untagged_text ||= reader.pages.flat_map { |page| MarkedText.read(page).unmarked }
      end

      private

      def objects = reader.objects

      def annotations
        reader.pages.flat_map do |page|
          Array(objects.deref_array(page.attributes[:Annots])).map do |ref|
            annot = objects.deref_hash(ref)
            annot.merge(A: objects.deref_hash(annot[:A]))
          end
        end
      end

      def destination(dest)
        return dest.to_s unless dest.is_a?(Array)

        objects.page_references.index(dest.first) + 1
      end

      def titles(item)
        return [] unless item

        [decode(item[:Title]), *titles(item[:First]), *titles(item[:Next])]
      end

      def decode(title)
        return title.dup.force_encoding(Encoding::UTF_8) unless title.b.start_with?(UTF16_BOM)

        title.b.byteslice(2..).force_encoding(Encoding::UTF_16BE).encode(Encoding::UTF_8)
      end
    end
  end
end
