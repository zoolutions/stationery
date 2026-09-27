# frozen_string_literal: true

module Stationery
  module Layout
    # An interactive form field: a widget `height` tall that fills the width
    # (`width: :full`) or takes `width` points. Its look comes from the
    # widget's own appearance, so it paints nothing into the page but an
    # optional `label` node to the right of the widget.
    class Field < Node
      LABEL_GAP = 6

      def initialize(field, height:, width: :full, label: nil)
        super()
        @field = field
        @height = height
        @width = width
        @label = label
        @tag = Tagging::Element.new(:Form, kind: :field)
      end

      def measure(width)
        @label ? [@height, @label.measure(label_width(width))].max : @height
      end

      def natural_width = @label ? label_offset + @label.natural_width : fixed_points || 0
      def min_width = @label ? label_offset + @label.min_width : fixed_points || 0

      def fixed_width(available)
        return [natural_width, available].min if @label

        fixed_points && [fixed_points, available].min
      end

      def paint(canvas, x, y, width, _height = nil, **)
        own = @label ? @width : width
        total = measure(width)
        top = y + ((total - @height) / 2.0)
        canvas.widget(@field, x, top, own, @height, tag: @tag)
        @label&.paint(canvas, x + label_offset, y + ((total - @label.measure(label_width(width))) / 2.0),
                      label_width(width))
        canvas.debug_rect(x, top, own, @height, :field) if canvas.debug?
      end

      private

      def fixed_points = @width.is_a?(Numeric) ? @width : nil
      def label_offset = @width + LABEL_GAP
      def label_width(width) = [width - label_offset, 0].max
    end
  end
end
