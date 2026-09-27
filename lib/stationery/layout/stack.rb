# frozen_string_literal: true

module Stationery
  module Layout
    # A base flow with layers painted over it. The base sets the height and
    # widths; each Layer is placed relative to the stack's rectangle and takes
    # no space, so it can overhang the edges. A stack never splits: it moves
    # to the next page whole (and is reported as an Overflow when taller than
    # a page).
    class Stack < Node
      attr_reader :base, :layers

      def initialize(base, layers)
        super()
        @base = base
        @layers = layers
      end

      def measure(width) = @base.measure(width)
      def natural_width = @base.natural_width
      def min_width = @base.min_width
      def fixed_width(available) = @base.fixed_width(available)
      def prefer_whole? = true

      def paint(canvas, x, y, width, height = nil, **)
        height ||= measure(width)
        @base.paint(canvas, x, y, width, height)
        @layers.each { |layer| layer.paint(canvas, x, y, width, height) }
        canvas.debug_rect(x, y, width, height, :stack)
      end
    end

    # A box placed over a Stack by CSS-like insets. `top:`, `right:`,
    # `bottom:`, `left:`, `width:` and `height:` are points, or fractions of
    # the stack's width (horizontal ones) or height (vertical ones) when given
    # as a Rational or a Float between -1 and 1; negative points overhang.
    # Without `left:`/`top:` the layer sits at the stack's left/top edge;
    # without `width:` it takes its content's natural width, at most the
    # stack's, and without `height:` its content's height.
    class Layer
      def initialize(box, top: nil, right: nil, bottom: nil, left: nil, width: nil, height: nil)
        @box = box
        @top = top
        @right = right
        @bottom = bottom
        @left = left
        @width = width
        @height = height
      end

      def paint(canvas, x, y, width, height)
        own = layer_width(width)
        tall = @height ? resolve(@height, height) : @box.measure(own)
        @box.paint(canvas, x + offset(@left, @right, width, own), y + offset(@top, @bottom, height, tall), own, tall)
      end

      private

      # Where the layer's near edge sits along one axis of the stack: `start`
      # points from the start edge, else `finish` points before the end edge.
      def offset(start, finish, extent, own)
        return resolve(start, extent) if start
        return extent - resolve(finish, extent) - own if finish

        0
      end

      def layer_width(width)
        return [@box.natural_width, width].min unless @width

        resolve(@width, width)
      end

      def resolve(value, extent)
        fraction?(value) ? extent * value : value
      end

      def fraction?(value) = value.is_a?(Rational) || (value.is_a?(Float) && value.abs <= 1)
    end
  end
end
