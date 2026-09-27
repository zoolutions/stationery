# frozen_string_literal: true

module Stationery
  module Layout
    # One row per outline entry: the title (indented by level), a leader and a
    # right-aligned page number filled in once pages are known. Rows are built
    # on first use, so bookmarks declared after the contents still appear.
    class TableOfContents < Node
      Options = Data.define(:levels, :leader, :indent, :number_width, :gap)

      def initialize(outline, context:, levels: 1.., leader: :dots, indent: 12, number_width: nil, gap: 4)
        super()
        @outline = outline
        @context = context
        @options = Options.new(levels, leader, indent, number_width, gap)
      end

      def splittable? = true
      def measure(width) = rows.measure(width)
      def natural_width = rows.natural_width
      def min_width = rows.min_width
      def split(width, height, **) = rows.split(width, height, **)
      def paint(canvas, x, y, width, height = nil, **) = rows.paint(canvas, x, y, width, height)

      private

      def rows
        @rows ||= Flow.new(entries.map { |entry| Entry.new(entry, context: @context, options: @options, slot:) },
                           gap: @options.gap)
      end

      def entries
        levels = @options.levels
        @outline.entries.select { |entry| levels.is_a?(Integer) ? entry.level <= levels : levels.include?(entry.level) }
      end

      def slot
        style = @context.style
        @options.number_width || @context.book.resolve(style).first.width_of("0000", style.render_size)
      end
    end
  end
end
