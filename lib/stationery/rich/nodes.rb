# frozen_string_literal: true

module Stationery
  # The block model rich-text parsers (HTML, Markdown) produce and elements render.
  module Rich
    # A run of text with its marks: any of bold:, italic:, underline:, strike:, code:, link: (href),
    # script: (:sub/:sup) and break: true, a hard line break whose text is "".
    Inline = Data.define(:text, :marks) do
      def self.break = new(text: "", marks: { break: true })

      def initialize(text:, marks: {}) = super(text: text.to_s, marks: marks.frozen? ? marks : marks.dup.freeze)
      def break? = marks[:break] == true
    end

    Paragraph = Data.define(:inlines)
    Heading = Data.define(:level, :inlines)
    List = Data.define(:ordered, :start, :items)
    Blockquote = Data.define(:blocks)
    CodeBlock = Data.define(:text, :language)
    Rule = Data.define
    Table = Data.define(:rows)
    Cell = Data.define(:header, :align, :blocks)
    Image = Data.define(:src, :alt, :width, :height)

    # Operations on inline sequences shared by the parsers.
    module Inlines
      module_function

      # Joins adjacent inlines with equal marks and drops empty ones; breaks and images pass through.
      def merge(items)
        items.each_with_object([]) do |item, merged|
          next merged << item unless item.is_a?(Inline) && !item.break?
          next if item.text.empty?

          last = merged.last
          if last.is_a?(Inline) && !last.break? && last.marks == item.marks
            merged[-1] = last.with(text: last.text + item.text)
          else
            merged << item
          end
        end
      end

      # Groups inlines into paragraphs, with each image standing as a block between them.
      def paragraphs(items)
        items.chunk_while { |a, b| !a.is_a?(Image) && !b.is_a?(Image) }.filter_map do |run|
          next run.first if run.first.is_a?(Image)

          inlines = merge(block_given? ? yield(run) : run)
          Paragraph.new(inlines:) unless inlines.empty?
        end
      end
    end
  end
end
