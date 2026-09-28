# frozen_string_literal: true

require_relative "flow/placement"
require_relative "flow/floating"

module Stationery
  module Layout
    # Children stacked top to bottom: the document body and every box's
    # content. Splits across pages: a splittable child continues on the next
    # page (one that prefers staying whole only from the top of a fresh page),
    # anything else moves there whole, a spacer at the break is dropped and a
    # child marked keep_with_next moves with its successor. A Floated child
    # goes to one side and what follows it wraps beside it (Flow::Floating).
    class Flow < Node
      include Floating

      attr_reader :children, :gap, :align

      # `tag` groups the children in a tagged PDF (a list's L).
      def initialize(children = [], gap: 0, align: :left, tag: nil)
        super()
        @children = children
        @gap = gap
        @align = align
        @tag = tag
      end

      def <<(child)
        @children << child
        @breaks = nil
        @floats = nil
        forget_measures
        self
      end

      # A flow holding a page break (at any depth) is cut there even when it
      # would fit on the page it is on.
      def breaks?
        @breaks = @children.any? { |child| child.page_break? || child.breaks? } if @breaks.nil?
        @breaks
      end

      def leading_break?
        first = @children.first
        !first.nil? && (first.page_break? || first.leading_break?)
      end

      def splittable? = true
      def wraps? = true
      def decorated? = @children.any?(&:decorated?)
      def natural_width = floats? ? natural_width_beside : @children.map(&:natural_width).max || 0
      def min_width = @children.map(&:min_width).max || 0

      def measure(width, exclusions: nil)
        return measure_beside(width, exclusions) if exclusions || floats?

        memoize_by_width(width) do
          visible = @children.reject(&:page_break?)
          visible.sum { |child| child.measure(child.width_in(width)) } + (@gap * [visible.size - 1, 0].max)
        end
      end

      def paint(canvas, x, y, width, _height = nil, exclusions: nil)
        return canvas.structure(@tag) { paint_beside(canvas, x, y, width, exclusions) } if exclusions || floats?

        canvas.structure(@tag) { paint_children(canvas, x, y, width) }
      end

      def split(width, height, fresh: false, exclusions: nil)
        Splitter.new(self, width, height, fresh, exclusions).call
      end

      def with_children(children)
        self.class.new(children, gap: @gap, align: @align, tag: @tag)
      end

      private

      def paint_children(canvas, x, y, width)
        cursor = y
        @children.reject(&:page_break?).each_with_index do |child, index|
          cursor += @gap unless index.zero?
          own = child.width_in(width)
          left = child.fixed_width(width) ? x + Geometry.align_offset(@align, width, own) : x
          child.paint(canvas, left, cursor, own)
          height = child.measure(own)
          canvas.debug_rect(left, cursor, own, height, :flow)
          cursor += height
        end
      end
    end
  end
end

require_relative "flow/splitter"
