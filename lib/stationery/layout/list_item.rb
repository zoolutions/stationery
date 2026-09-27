# frozen_string_literal: true

module Stationery
  module Layout
    # One list entry: a marker right-aligned in the column before `indent`
    # (`marker_gap` short of it) and a body flow beside it. Splits inside the
    # body; the marker stays with the first fragment and never leaves its
    # first line behind.
    class ListItem < Node
      attr_reader :marker, :body, :indent, :marker_gap

      def initialize(marker, body, indent:, marker_gap:)
        super()
        @marker = marker
        @body = body
        @indent = indent
        @marker_gap = marker_gap
      end

      def splittable? = @body.splittable?
      def natural_width = @indent + @body.natural_width
      def min_width = @indent + @body.min_width
      def break_inside = @body.break_inside

      def break_inside=(value)
        @body.break_inside = value
      end

      def measure(width)
        [@marker ? @marker.measure(column) : 0, @body.measure(body_width(width))].max
      end

      def paint(canvas, x, y, width, _height = nil, **)
        if @marker
          own = @marker.width_in(column)
          @marker.paint(canvas, x + column - own, y, own)
        end
        @body.paint(canvas, x + @indent, y, body_width(width))
      end

      def split(width, height, fresh: false)
        return [self, nil] if measure(width) <= height + EPSILON

        head, tail = @body.split(body_width(width), height, fresh:)
        return [nil, self] unless head

        [with(@marker, head), tail && with(nil, tail).tap { |rest| rest.keep_with_next = keep_with_next }]
      end

      private

      def column = [@indent - @marker_gap, 0].max
      def body_width(width) = [width - @indent, 0].max
      def with(marker, body) = self.class.new(marker, body, indent: @indent, marker_gap: @marker_gap)
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
