# frozen_string_literal: true

module Stationery
  module Layout
    EPSILON = 0.0001

    # What text nodes need to measure: the document's fonts and the base style.
    Context = Data.define(:book, :style)

    # A node placed taller than the space a page had for it.
    Overflow = Data.define(:page, :height, :available) do
      def message
        format("content %<height>.1fpt tall placed on page %<page>d with %<available>.1fpt available",
               height:, page:, available:)
      end
    end

    # The layout protocol. Every node can:
    #
    # - measure(width)            → its height at that width
    # - paint(canvas, x, y, width, height = nil, **)
    # - split(width, height)      → [part that fits, remainder] (nil for an empty side)
    # - natural_width / min_width → its preferred and narrowest widths
    # - fixed_width(available)    → its own width, or nil when it fills the width
    class Node
      attr_accessor :keep_with_next, :break_inside

      def measure(_width) = raise(NotImplementedError, "#{self.class} must implement measure")
      def paint(_canvas, _x, _y, _width, _height = nil, **) = raise(NotImplementedError, "#{self.class}#paint")

      def splittable? = false
      def natural_width = 0
      def min_width = 0
      def fixed_width(_available) = nil
      def page_break? = false

      def split(width, height)
        measure(width) <= height + EPSILON ? [self, nil] : [nil, self]
      end

      def avoid_break?
        break_inside == :avoid || !splittable?
      end
    end
  end
end
