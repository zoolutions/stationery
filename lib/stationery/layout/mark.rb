# frozen_string_literal: true

module Stationery
  module Layout
    # Takes up no space and paints nothing. Unlike a Spacer it survives a page
    # break, so a standalone anchor is never dropped.
    class Empty < Node
      def measure(_width) = 0
      def paint(*, **) = nil
    end

    # Names a node as a link target: its top is recorded as an anchor for each
    # name where it is painted. When the node splits, the names stay with the
    # first fragment.
    class Mark < Node
      attr_reader :child, :names

      def self.standalone(name)
        new(Empty.new, [name.to_s]).tap { |mark| mark.keep_with_next = true }
      end

      def initialize(child, names)
        super()
        @child = child
        @names = names
      end

      def measure(width) = @child.measure(width)
      def natural_width = @child.natural_width
      def min_width = @child.min_width
      def fixed_width(available) = @child.fixed_width(available)
      def splittable? = @child.splittable?
      def page_break? = @child.page_break?
      def avoid_break? = @child.avoid_break?
      def keep_with_next = @child.keep_with_next

      def keep_with_next=(value)
        @child.keep_with_next = value
      end

      def break_inside = @child.break_inside

      def break_inside=(value)
        @child.break_inside = value
      end

      def paint(canvas, x, y, width, height = nil, **)
        @names.each { |name| canvas.anchor(name, y) }
        @child.paint(canvas, x, y, width, height, **)
      end

      def split(width, height, **)
        head, tail = @child.split(width, height, **)
        [head && Mark.new(head, @names), tail]
      end
    end
  end
end
