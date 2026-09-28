# frozen_string_literal: true

module Stationery
  module Layout
    class Flow < Node
      # One pass of Flow#split, kept apart so the rules read top to bottom.
      # In a flow with floats a Placement says where each child goes. A float
      # never splits: one that does not fit what is left of the page, or whose
      # following content would not start beside it there, moves to the next
      # page with that content; floats left last on a page by a child that
      # moves on go with it.
      class Splitter
        def initialize(flow, width, height, fresh, exclusions = nil)
          @flow = flow
          @width = width
          @height = height
          @fresh = fresh
          @placed = []
          @used = 0
          @placement = Placement.new(flow, width, exclusions) if exclusions || flow.floats?
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
          return float(child, rest) if child.float?

          @slot = @placement&.slot(child)
          gap = @placed.empty? ? 0 : @flow.gap
          remaining = @slot ? @height - @slot.top : @height - @used - gap
          return broken(child, gap, remaining, rest) if child.breaks?

          height = measure(child)
          return fits(child, height, gap, remaining - height, rest) if height <= remaining + EPSILON
          return [part(@placed), part(rest)] if child.is_a?(Spacer)

          split_or_move(child, remaining, rest)
        end

        def page_break(rest)
          return nil if @placed.empty?

          [part(@placed), part(rest)]
        end

        def float(child, rest)
          return move([child, *rest]) unless top? || lands?([child, *rest], @placement)

          @placement.float(child)
          @placed << child
          nil
        end

        # A child holding a page break: what comes before the break stays on
        # this page, the rest goes to the next, however much room is left. One
        # that starts with the break goes to the next page whole.
        def broken(child, gap, remaining, rest)
          return [part(@placed), part([child, *rest])] if child.leading_break? && !@placed.empty?

          head, tail = cut(child, remaining)
          return split_or_move(child, remaining, rest) unless head
          return [part(@placed + [head]), part([tail, *rest])] if tail

          height = measure(head)
          fits(head, height, gap, remaining - height, rest)
        end

        def fits(child, height, gap, left_after, rest)
          @placement&.advance(@slot, height)
          return move([child, *rest]) if strand?(child, left_after, rest)

          @placed << child
          @used += height + gap
          nil
        end

        # keep_with_next: true needs the start of the next child on this page; a
        # number needs that many points of what follows (or all of it, if less).
        def strand?(child, left_after, rest)
          want = child.keep_with_next
          return false unless want && rest.any? && !top?
          return !starts?(rest, left_after) unless want.is_a?(Numeric)

          following = 0
          rest.each do |node|
            following += node.measure(node.width_in(@width))
            break if following >= want
          end
          left_after + EPSILON < [want, following].min
        end

        def split_or_move(child, remaining, rest)
          if may_split?(child)
            head, tail = cut(child, remaining)
            # A nested flow can finish on this page (its trailing spacer
            # dropped at the break) and hand back no remainder.
            return [part(@placed + [head]), part([tail, *rest].compact)] if head
          end
          return [part(@placed.empty? ? [child] : @placed + [child]), part(rest)] if top?

          move([child, *rest])
        end

        def may_split?(child, top: top?)
          !child.avoid_break? && (!child.prefer_whole? || top)
        end

        # Whether nothing but floats is above on a fresh page.
        def top? = @fresh && (@placement ? !@placement.content? : @placed.empty?)

        def measure(child) = @slot ? @slot.measure(child) : child.measure(child.width_in(@width))

        def cut(child, remaining)
          return @slot.split(child, remaining, fresh: top?) if @slot

          child.split(child.width_in(@width), remaining, fresh: top?)
        end

        # The break before `nodes`. Floats placed last go with them: what
        # wraps beside them is the first of `nodes`.
        def move(nodes)
          return [part(@placed), part(nodes)] unless @placement && @placed.last&.float?

          kept = @placed.reverse.drop_while(&:float?).reverse
          [part(kept), part(@placed.drop(kept.size) + nodes)]
        end

        # Whether any of what follows would be placed in `height` below other content.
        def starts?(rest, height)
          return lands?(rest, @placement) if @placement

          start?(rest.first, rest.first.width_in(@width), height)
        end

        def start?(node, width, height)
          return !node.split(width, height).first.nil? if may_split?(node, top: false)

          node.measure(width) <= height + EPSILON
        end

        # With floats: whether the floats next in `rest` fit whole and the
        # first child after them starts beside them. Tried on a copy of the
        # placement, so nothing is placed.
        def lands?(rest, placement)
          placement = placement.dup
          rest.each do |node|
            break if node.page_break?

            slot = node.float? ? placement.float(node) : placement.slot(node)
            return landed?(node, slot) unless node.float?
            return false if slot.top + node.measure(slot.width) > @height + EPSILON
          end
          true
        end

        def landed?(node, slot)
          room = @height - slot.top
          return !slot.split(node, room, fresh: false).first.nil? if may_split?(node, top: false)

          slot.measure(node) <= room + EPSILON
        end

        def part(children)
          children.empty? ? nil : @flow.with_children(children)
        end
      end
    end
  end
end
