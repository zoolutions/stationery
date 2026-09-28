# frozen_string_literal: true

module Stationery
  module Layout
    # One list entry: a marker right-aligned in the column before `indent`
    # (`marker_gap` short of it) and a body flow beside it. Splits inside the
    # body; the marker stays with the first fragment and never leaves its
    # first line behind. Beside floats (`exclusions:`) the body wraps: its
    # lines keep the indent from the float beside them, the marker goes
    # beside the first, and below the floats they take the full width.
    class ListItem < Node
      attr_reader :marker, :body, :indent, :marker_gap

      # `tag` and `body_tag` are the item's LI and LBody; a Text marker carries its own Lbl.
      def initialize(marker, body, indent:, marker_gap:, tag: Tagging::Element.new(:LI),
                     body_tag: Tagging::Element.new(:LBody))
        super()
        @tag = tag
        @body_tag = body_tag
        @marker = marker
        @body = body
        @indent = indent
        @marker_gap = marker_gap
      end

      def splittable? = @body.splittable?
      def wraps? = @body.wraps?
      def natural_width = @indent + @body.natural_width
      def min_width = @indent + @body.min_width
      def break_inside = @body.break_inside

      def break_inside=(value)
        @body.break_inside = value
      end

      def measure(width, exclusions: nil)
        memoize_by_width(exclusions ? [width, exclusions] : width) do
          slot = beside(width, exclusions)
          [@marker ? @marker.measure(column) : 0, slot ? slot.measure(@body) : @body.measure(body_width(width))].max
        end
      end

      def paint(canvas, x, y, width, _height = nil, exclusions: nil)
        slot = beside(width, exclusions)
        canvas.structure(@tag) do
          if @marker
            own = @marker.width_in(column)
            @marker.paint(canvas, x + taken(exclusions) + column - own, y, own)
          end
          canvas.structure(@body_tag) do
            slot ? slot.paint(@body, canvas, x, y) : @body.paint(canvas, x + @indent, y, body_width(width))
          end
        end
      end

      def split(width, height, fresh: false, exclusions: nil)
        return [self, nil] if measure(width, exclusions:) <= height + EPSILON

        slot = beside(width, exclusions)
        head, tail = slot ? slot.split(@body, height, fresh:) : @body.split(body_width(width), height, fresh:)
        return [nil, self] unless head

        [with(@marker, head), tail && with(nil, tail).tap { |rest| rest.keep_with_next = keep_with_next }]
      end

      private

      def column = [@indent - @marker_gap, 0].max

      # Where the body goes beside floats: measure, split and paint place it
      # by this one slot. It meets the floats as the item does, so its lines
      # are as far from a float at their left as they are from the marker.
      # nil without floats.
      def beside(width, exclusions)
        exclusions && Flow::Placement::Slot.new(top: 0, left: @indent, width: body_width(width), exclusions:)
      end

      # What the floats take from the left of the marker's line.
      def taken(exclusions) = exclusions ? exclusions.insets(0, @marker.measure(column)).first : 0
      def body_width(width) = [width - @indent, 0].max

      def with(marker, body)
        self.class.new(marker, body, indent: @indent, marker_gap: @marker_gap, tag: @tag, body_tag: @body_tag)
      end
    end

    # A drawn bullet (:disc, :circle or :square) sized to the text style and
    # centred on its x-height.
    class Bullet < Node
      SIZE = 0.36
      STROKE = 0.06

      def initialize(shape, style:, context:)
        super()
        @shape = shape
        @style = style
        @font = context.book.resolve(style).first
      end

      def measure(_width) = @font.line_height(@style.size)
      def fixed_width(_available) = diameter
      def natural_width = diameter

      def paint(canvas, x, y, _width, _height = nil, **)
        radius = diameter / 2.0
        cy = y + @font.ascender(@style.size) - (@font.x_height(@style.size) / 2.0)
        case @shape
        when :circle then canvas.circle(x + radius, cy, radius, stroke: @style.color, line_width: STROKE * @style.size)
        when :square then canvas.fill_rect(x, cy - radius, diameter, diameter, color: @style.color)
        else canvas.circle(x + radius, cy, radius, fill: @style.color)
        end
      end

      private

      def diameter = SIZE * @style.size
    end
  end
end
