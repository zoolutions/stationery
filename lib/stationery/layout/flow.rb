# frozen_string_literal: true

module Stationery
  module Layout
    # Children stacked top to bottom: the document body and every box's
    # content. Splits across pages: a splittable child continues on the next
    # page, anything else moves there whole, a spacer at the break is dropped
    # and a child marked keep_with_next moves with its successor.
    class Flow < Node
      attr_reader :children, :gap, :align

      def initialize(children = [], gap: 0, align: :left)
        super()
        @children = children
        @gap = gap
        @align = align
      end

      def <<(child)
        @children << child
        self
      end

      def splittable? = true
      def natural_width = @children.map(&:natural_width).max || 0
      def min_width = @children.map(&:min_width).max || 0

      def measure(width)
        visible = @children.reject(&:page_break?)
        visible.sum { |child| child.measure(width) } + (@gap * [visible.size - 1, 0].max)
      end

      def paint(canvas, x, y, width, _height = nil, **)
        cursor = y
        @children.reject(&:page_break?).each_with_index do |child, index|
          cursor += @gap unless index.zero?
          own = child.fixed_width(width)
          left = own ? x + Geometry.align_offset(@align, width, own) : x
          child.paint(canvas, left, cursor, own || width)
          height = child.measure(width)
          canvas.debug_rect(left, cursor, own || width, height, :flow)
          cursor += height
        end
      end

      def split(width, height, fresh: false)
        Splitter.new(self, width, height, fresh).call
      end

      def with_children(children)
        self.class.new(children, gap: @gap, align: @align)
      end
    end

    # One pass of Flow#split, kept apart so the rules read top to bottom.
    class Flow
      class Splitter
        def initialize(flow, width, height, fresh)
          @flow = flow
          @width = width
          @height = height
          @fresh = fresh
          @placed = []
          @used = 0
        end

        def call
          children = @flow.children
          children.each_with_index do |child, index|
            rest = children.drop(index + 1)
            result = place(child, rest)
            return result if result
          end
          [part(@placed), nil]
        end

        private

        def place(child, rest)
          return page_break(rest) if child.page_break?

          gap = @placed.empty? ? 0 : @flow.gap
          remaining = @height - @used - gap
          height = child.measure(@width)
          return fits(child, height + gap, remaining - height, rest) if height <= remaining + EPSILON
          return [part(@placed), part(rest)] if child.is_a?(Spacer)

          split_or_move(child, remaining, rest)
        end

        def page_break(rest)
          return nil if @placed.empty?

          [part(@placed), part(rest)]
        end

        def fits(child, consumed, left_after, rest)
          return [part(@placed), part([child, *rest])] if strand?(child, left_after, rest)

          @placed << child
          @used += consumed
          nil
        end

        # keep_with_next: true needs the start of the next child on this page; a
        # number needs that many points of what follows (or all of it, if less).
        def strand?(child, left_after, rest)
          want = child.keep_with_next
          return false unless want && rest.any? && !@placed.empty?
          return rest.first.split(@width, left_after).first.nil? unless want.is_a?(Numeric)

          following = 0
          rest.each do |node|
            following += node.measure(@width)
            break if following >= want
          end
          left_after + EPSILON < [want, following].min
        end

        def split_or_move(child, remaining, rest)
          unless child.avoid_break?
            head, tail = child.split(@width, remaining)
            # A nested flow can finish on this page (its trailing spacer
            # dropped at the break) and hand back no remainder.
            return [part(@placed + [head]), part([tail, *rest].compact)] if head
          end
          return [part([child]), part(rest)] if @placed.empty? && @fresh

          @placed.empty? ? [nil, part([child, *rest])] : [part(@placed), part([child, *rest])]
        end

        def part(children)
          children.empty? ? nil : @flow.with_children(children)
        end
      end
    end
  end
end
