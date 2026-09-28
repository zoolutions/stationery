# frozen_string_literal: true

module Stationery
  module Layout
    # Children stacked top to bottom: the document body and every box's
    # content. Splits across pages: a splittable child continues on the next
    # page (one that prefers staying whole only from the top of a fresh page),
    # anything else moves there whole, a spacer at the break is dropped and a
    # child marked keep_with_next moves with its successor.
    class Flow < Node
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
      def natural_width = @children.map(&:natural_width).max || 0
      def min_width = @children.map(&:min_width).max || 0

      def measure(width)
        memoize_by_width(width) do
          visible = @children.reject(&:page_break?)
          visible.sum { |child| child.measure(child.width_in(width)) } + (@gap * [visible.size - 1, 0].max)
        end
      end

      def paint(canvas, x, y, width, _height = nil, **)
        canvas.structure(@tag) { paint_children(canvas, x, y, width) }
      end

      def split(width, height, fresh: false)
        Splitter.new(self, width, height, fresh).call
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
          return broken(child, gap, remaining, rest) if child.breaks?

          height = child.measure(child.width_in(@width))
          return fits(child, height + gap, remaining - height, rest) if height <= remaining + EPSILON
          return [part(@placed), part(rest)] if child.is_a?(Spacer)

          split_or_move(child, remaining, rest)
        end

        def page_break(rest)
          return nil if @placed.empty?

          [part(@placed), part(rest)]
        end

        # A child holding a page break: what comes before the break stays on
        # this page, the rest goes to the next, however much room is left. One
        # that starts with the break goes to the next page whole.
        def broken(child, gap, remaining, rest)
          return [part(@placed), part([child, *rest])] if child.leading_break? && !@placed.empty?

          head, tail = child.split(child.width_in(@width), remaining, fresh: @fresh && @placed.empty?)
          return split_or_move(child, remaining, rest) unless head
          return [part(@placed + [head]), part([tail, *rest])] if tail

          height = head.measure(head.width_in(@width))
          fits(head, height + gap, remaining - height, rest)
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
          return !starts?(rest.first, left_after) unless want.is_a?(Numeric)

          following = 0
          rest.each do |node|
            following += node.measure(node.width_in(@width))
            break if following >= want
          end
          left_after + EPSILON < [want, following].min
        end

        def split_or_move(child, remaining, rest)
          if may_split?(child)
            head, tail = child.split(child.width_in(@width), remaining, fresh: @fresh && @placed.empty?)
            # A nested flow can finish on this page (its trailing spacer
            # dropped at the break) and hand back no remainder.
            return [part(@placed + [head]), part([tail, *rest].compact)] if head
          end
          return [part([child]), part(rest)] if @placed.empty? && @fresh

          @placed.empty? ? [nil, part([child, *rest])] : [part(@placed), part([child, *rest])]
        end

        def may_split?(child, top: @placed.empty? && @fresh)
          !child.avoid_break? && (!child.prefer_whole? || top)
        end

        # Whether any of `node` would be placed in `height` below other content.
        def starts?(node, height)
          width = node.width_in(@width)
          return !node.split(width, height).first.nil? if may_split?(node, top: false)

          node.measure(width) <= height + EPSILON
        end

        def part(children)
          children.empty? ? nil : @flow.with_children(children)
        end
      end
    end
  end
end
