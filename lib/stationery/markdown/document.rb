# frozen_string_literal: true

require_relative "block_parser"
require_relative "inline_parser"

module Stationery
  # A CommonMark subset (plus GFM tables and strikethrough) to rich-text blocks (see Stationery::Rich).
  module Markdown
    def self.parse(source)
      refs = {}
      Resolver.new(refs).blocks(BlockParser.parse(source, refs))
    end

    # Runs the raw text the block parser left in paragraphs, headings and cells through the inline parser.
    class Resolver
      def initialize(refs)
        @refs = refs
      end

      def blocks(blocks) = blocks.flat_map { |block| block(block) }

      private

      def block(block)
        case block
        when Rich::Paragraph then Rich::Inlines.paragraphs(inlines(block.inlines)) { |run| trim(run) }
        when Rich::Heading then [block.with(inlines: Rich::Inlines.merge(inlines(block.inlines).map { |i| alt(i) }))]
        when Rich::List then [block.with(items: block.items.map { |item| blocks(item) })]
        when Rich::Blockquote then [block.with(blocks: blocks(block.blocks))]
        when Rich::Table then [block.with(rows: block.rows.map { |row| cells(row) })]
        else [block]
        end
      end

      def cells(row) = row.map { |cell| cell.with(blocks: blocks(cell.blocks)) }

      def inlines(text) = InlineParser.parse(text, @refs)

      def alt(item) = item.is_a?(Rich::Image) ? Rich::Inline.new(text: item.alt) : item

      # Text around an image loses the space that separated it from the image.
      def trim(run)
        run = run.dup
        run[0] = run[0].with(text: run[0].text.lstrip) unless run[0].break?
        run[-1] = run[-1].with(text: run[-1].text.rstrip) unless run[-1].break?
        run
      end
    end
  end
end
