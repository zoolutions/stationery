# frozen_string_literal: true

module Stationery
  module Layout
    class TableOfContents
      # One contents row. The title wraps within the room the number slot
      # leaves; the leader and the number sit on its last line, and the whole
      # row links to the entry's anchor.
      class Entry < Node
        LEADERS = { dots: { dash: [0, 3], cap: :round, width: 1 }, line: { width: 0.5 } }.freeze

        def initialize(entry, context:, options:, slot:)
          super()
          @entry = entry
          @context = context
          @options = options
          @slot = slot
          @paragraphs = {}
        end

        def measure(width) = paragraph(width).height
        def natural_width = paragraph(Float::INFINITY).lines.map(&:width).max.to_f + offset + @slot + @options.gap

        def paint(canvas, x, y, width, _height = nil, **)
          text = paragraph(width)
          text.draw(canvas, x + offset, y)
          last = text.lines.last
          baseline = y + text.height - last.height + last.ascent
          slot_x = x + width - @slot
          draw_leader(canvas, x + offset + last.width + 2, slot_x, baseline)
          canvas.number_slot(@entry.anchor, x: slot_x, baseline:, width: @slot, style: @context.style)
          canvas.link(x + offset, y, width - offset, text.height, "##{@entry.anchor}")
        end

        private

        def offset = @options.indent * (@entry.level - 1)

        def draw_leader(canvas, from, to, baseline)
          leader = LEADERS[@options.leader]
          return unless leader && to > from

          canvas.line(from, baseline, to, baseline, color: @context.style.color, **leader)
        end

        def paragraph(width)
          @paragraphs[width] ||= ::Stationery::Text::Paragraph.new(
            [::Stationery::Text::Run.new(@entry.title, @context.style)],
            book: @context.book, width: [width - offset - @slot - @options.gap, 1].max,
            fallback_style: @context.style
          )
        end
      end
    end
  end
end
