# frozen_string_literal: true

module Stationery
  module Rich
    class Renderer
      # What a block's CSS style becomes around the block: margins as spacers
      # above and below and as an indent from the sides, a background and
      # padding as a box, a column count as columns,
      # page-break rules as page breaks and kept-together groups, borders and
      # widths as table options.
      module Boxes
        PADDING = { padding_top: 0, padding_right: 1, padding_bottom: 2, padding_left: 3 }.freeze
        MARGIN = { margin_top: 0, margin_right: 1, margin_bottom: 2, margin_left: 3 }.freeze

        private

        # Draws the block inside its margins and its box. A block styled with
        # nothing but an alignment draws as it is.
        def styled(style, block = nil, &)
          return yield if style.empty?

          spaced(style, block) { boxed(style) { columned(style, &) } }
        end

        # The block's content poured through balanced columns.
        def columned(style, &)
          count = style[:columns]
          return yield unless count && count > 1

          gap = style[:column_gap]
          @component.columns(count:, **({ gap: } if gap), &)
        end

        # Page breaks and margins around the block, and the rule that keeps it
        # on one page.
        def spaced(style, block = nil, &)
          return yield if style.empty?

          top, right, bottom, left = margins(style)
          content = indented_by(left, right, block, &)
          return content.call unless spacing?(style, top, bottom)

          @component.page_break if style[:break_before]
          @component.group(keep_together: style[:keep_together] == true) do
            @component.spacer(top) if top.positive?
            content.call
            @component.spacer(bottom) if bottom.positive?
          end
          @component.page_break if style[:break_after]
        end

        def spacing?(style, top, bottom)
          style[:break_before] || style[:break_after] || style[:keep_together] || top.positive? || bottom.positive?
        end

        # [top, right, bottom, left]: each side of `margin`, or the side's own
        # when it has one. A negative margin is drawn as none.
        def margins(style)
          all = style[:margin]
          MARGIN.map { |key, index| [style[key] || all&.[](index) || 0, 0].max }
        end

        # What draws the block in from the sides. It breaks across pages and
        # stays with what follows as the block would without the margins.
        def indented_by(left, right, block, &content)
          return content unless left.positive? || right.positive?

          keep_with_next = keep_with_next(block)
          -> { @component.box(padding: [0, right, 0, left], break_inside: :auto, keep_with_next:, &content) }
        end

        # What `styles:` says of a paragraph or a heading and the block after it.
        def keep_with_next(block)
          case block
          when Paragraph then @styles[:p][:keep_with_next]
          when Heading then @styles[:"h#{block.level}"][:keep_with_next]
          end
        end

        def boxed(style, &)
          options = box_options(style)
          options.empty? ? yield : @component.box(**options, &)
        end

        # The background and padding a style gives a box, to merge over a
        # block's own (`styles[:blockquote]`, `styles[:pre]`).
        def box_options(style)
          options = {}
          options[:background] = style[:background] if style[:background]
          padding = padding_of(style)
          options[:padding] = padding if padding
          options
        end

        def padding_of(style)
          sides = PADDING.select { |key, _| style[key] }
          return style[:padding] if sides.empty?

          padding = (style[:padding] || [0, 0, 0, 0]).dup
          sides.each { |key, index| padding[index] = style[key] }
          padding
        end

        def aligned(style) = style[:align] ? { align: style[:align] } : {}

        # Where an image goes: floated to a side, its CSS margins (else
        # `styles[:img][:float_margin]`) kept around it, or aligned.
        def placed(style)
          return aligned(style) unless style[:float]

          own = style[:margin] || MARGIN.keys.any? { |key| style[key] }
          { float: style[:float], margin: own ? margins(style) : @styles[:img][:float_margin] }
        end

        def border_options(border)
          return {} unless border
          return { borders: [] } if border[:width].zero?

          { border_width: border[:width], border_color: border[:color] }
        end

        def cell_options(style)
          options = border_options(style[:border]).merge(box_options(style))
          options[:borders] = %i[top right bottom left] if options[:border_width]
          options
        end

        # Column widths from the first row, when every cell of it has one. A
        # percentage is a share of the table, which then takes the full width
        # unless it has a width of its own.
        def column_widths(table)
          widths = table.rows.first.map { |cell| cell.style[:width] }
          return {} unless widths.all?

          widths.any? { |width| fraction?(width) } && !table.style[:width] ? { widths:, width: :full } : { widths: }
        end

        # A table's own width: points, the full width for 100%, or a share of
        # the space through a box of that width.
        def sized(width)
          return yield({}) unless width
          return yield({ width: }) unless fraction?(width)
          return yield({ width: :full }) if width >= 1

          @component.box(width:) { yield({ width: :full }) }
        end

        def fraction?(value) = value.is_a?(Float) && value <= 1
      end
    end
  end
end
