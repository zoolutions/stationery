# frozen_string_literal: true

module Stationery
  module Layout
    # A node taken out of its flow to the left or right edge: what follows it
    # in the flow starts at the same top and wraps beside it (see
    # Flow::Placement). `margin:` is the space kept around it: a number is the
    # space towards the text (the inner side and the bottom), a Hash or an
    # Array names every side as `padding:` does. It never splits, and it
    # measures and paints with its margins, so where nothing wraps (a `wrap`
    # element) it is a block with space around it.
    class Floated < Node
      SIDES = %i[left right].freeze

      attr_reader :node, :side, :margin

      def initialize(node, side:, margin: 0)
        raise ArgumentError, "float: must be :left or :right, got #{side.inspect}" unless SIDES.include?(side)

        super()
        @node = node
        @side = side
        @margin = margin.is_a?(Numeric) ? facing(margin) : Geometry.box(margin)
      end

      def float? = true
      def tag = @node.tag
      def natural_width = @node.natural_width + horizontal

      # Its own width when it has one in points, else the least its node takes.
      def min_width
        own = @node.fixed_width(::Float::INFINITY)
        (own&.finite? ? own : @node.min_width) + horizontal
      end

      def fixed_width(available) = [@node.width_in(inner(available)) + horizontal, available].min
      def measure(width) = @node.measure(inner(width)) + @margin[0] + @margin[2]

      def paint(canvas, x, y, width, _height = nil, **)
        @node.paint(canvas, x + @margin[3], y + @margin[0], inner(width))
      end

      private

      def facing(margin) = @side == :left ? [0, margin, margin, 0] : [0, 0, margin, margin]
      def horizontal = @margin[1] + @margin[3]
      def inner(width) = [width - horizontal, 0].max
    end
  end
end
