# frozen_string_literal: true

module Stationery
  # The block model rich-text parsers (HTML, Markdown) produce and elements render.
  module Rich
    # A run of text with its marks: any of bold:, italic:, underline:, strike:, code:, link: (href),
    # script: (:sub/:sup), color: (a colour), size: (points), scale: (a factor of the text size)
    # and break: true, a hard line break whose text is "". A false bold:, italic:, underline: or
    # strike: switches the mark off inside an element that has it.
    Inline = Data.define(:text, :marks) do
      def self.break = new(text: "", marks: { break: true })

      def initialize(text:, marks: {}) = super(text: text.to_s, marks: marks.frozen? ? marks : marks.dup.freeze)
      def break? = marks[:break] == true
    end

    # Every block carries a `style` Hash from the source's CSS (see HTML::Css):
    # align:, background:, padding:, margin:/margin_top:/margin_bottom:,
    # border:, width:, break_before:, break_after:, keep_together:, columns:,
    # column_gap:, and float: on an image. Empty for Markdown and for HTML
    # without styles.
    Paragraph = Data.define(:inlines, :style) do
      def initialize(inlines:, style: {}) = super
    end
    Heading = Data.define(:level, :inlines, :style) do
      def initialize(level:, inlines:, style: {}) = super
    end
    List = Data.define(:ordered, :start, :items, :style) do
      def initialize(ordered:, start:, items:, style: {}) = super
    end
    Blockquote = Data.define(:blocks, :style) do
      def initialize(blocks:, style: {}) = super
    end
    CodeBlock = Data.define(:text, :language, :style) do
      def initialize(text:, language:, style: {}) = super
    end
    Rule = Data.define
    Table = Data.define(:rows, :style) do
      def initialize(rows:, style: {}) = super
    end
    Cell = Data.define(:header, :align, :blocks, :style) do
      def initialize(header:, align:, blocks:, style: {}) = super
    end
    Image = Data.define(:src, :alt, :width, :height, :style) do
      def initialize(src:, alt:, width:, height:, style: {}) = super
    end
    # A styled container (a `div` with a background, padding, margins or a
    # page-break rule) holding blocks; an unstyled one flattens into its parent.
    Container = Data.define(:blocks, :style)
    PageBreak = Data.define

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
      def paragraphs(items, style: {})
        items.chunk_while { |a, b| !a.is_a?(Image) && !b.is_a?(Image) }.filter_map do |run|
          next run.first if run.first.is_a?(Image)

          inlines = merge(block_given? ? yield(run) : run)
          Paragraph.new(inlines:, style:) unless inlines.empty?
        end
      end
    end
  end
end
