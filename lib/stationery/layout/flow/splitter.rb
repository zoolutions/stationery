# frozen_string_literal: true

module Stationery
  module Layout
    class Flow < Node
      # One pass of Flow#split, kept apart so the rules read top to bottom.
      # In a flow with floats a Placement says where each child goes. A float
      # never splits: one that does not fit what is left of the page, or whose
      # following content would not start beside it there, moves to the next
      # page with that content; floats left last on a page by a child that
      # moves on go with it. Floats that stack taller than a page are cut
      # between two of them.
      #
      # The children after the one being placed are named by its index and
      # copied only where the flow is cut: once a page, not once a child.
      class Splitter
        def initialize(flow, width, height, fresh, exclusions = nil)
          @flow = flow
          @children = flow.children
          @width = width
          @height = height
          @fresh = fresh
          @placed = []
          @used = 0
          @placement = Placement.new(flow, width, exclusions) if exclusions || flow.floats?
        end

        def call
          @children.each_with_index do |child, index|
            result = place(child, index)
            return result if result
          end
          [part(@placed), nil]
        end

        private

        def place(child, index)
          return page_break(index) if child.page_break?
          return float(child, index) if child.float?

          @slot = @placement&.slot(child)
          gap = @placed.empty? ? 0 : @flow.gap
          remaining = @slot ? @height - @slot.top : @height - @used - gap
          return broken(child, gap, remaining, index) if child.breaks?

          height = within(child, remaining)
          return fits(child, height, gap, remaining - height, index) if height <= remaining + EPSILON
          return [part(@placed), part(after(index))] if child.is_a?(Spacer)

          split_or_move(child, remaining, index)
        end

        # The children that follow the one at `index`.
        def after(index) = @children.drop(index + 1)

        def page_break(index)
          return nil if @placed.empty?

          [part(@placed), part(after(index))]
        end

        # Below other content a float is placed when the floats written with
        # it fit and what follows them starts beside them. Below nothing but
        # floats on a fresh page it is placed when it fits itself: the first
        # one always, so that one taller than the page is kept and reported.
        def float(child, index)
          return move(@children.drop(index)) unless top? || lands?(@children.drop(index), @placement)

          slot = @placement.float(child)
          return [part(@placed), part(@children.drop(index))] unless @placed.empty? || fits?(child, slot)

          @placed << child
          nil
        end

        def fits?(float, slot) = slot.top + float.measure(slot.width) <= @height + EPSILON

        # A child holding a page break: what comes before the break stays on
        # this page, the rest goes to the next, however much room is left. One
        # that starts with the break goes to the next page whole.
        def broken(child, gap, remaining, index)
          return [part(@placed), part([child, *after(index)])] if child.leading_break? && !@placed.empty?

          head, tail = cut(child, remaining)
          return split_or_move(child, remaining, index) unless head
          return [part(@placed + [head]), part([tail, *after(index)])] if tail

          height = measure(head)
          fits(head, height, gap, remaining - height, index)
        end

        def fits(child, height, gap, left_after, index)
          @placement&.advance(@slot, height)
          return move([child, *after(index)]) if strand?(child, left_after, index)

          @placed << child
          @used += height + gap
          nil
        end

        # keep_with_next: true needs the start of the next child on this page; a
        # number needs that many points of what follows (or all of it, if less).
        def strand?(child, left_after, index)
          want = child.keep_with_next
          return false unless want && index + 1 < @children.size && !top?
          return !starts?(index + 1, left_after) unless want.is_a?(Numeric)

          following = 0
          (index + 1).upto(@children.size - 1) do |at|
            node = @children[at]
            following += node.height_within(node.width_in(@width), want - following)
            break if following >= want
          end
          left_after + EPSILON < [want, following].min
        end

        def split_or_move(child, remaining, index)
          rest = after(index)
          if may_split?(child)
            head, tail = cut(child, remaining)
            # A nested flow can finish on this page (its trailing spacer
            # dropped at the break) and hand back no remainder.
            return [part(@placed + [head]), part([tail, *rest].compact)] if head && !over?(head, remaining)
          end
          return [part(@placed.empty? ? [child] : @placed + [child]), part(rest)] if top? && !leaves?(child)

          move([child, *rest])
        end

        # Whether the part of a child cut below the floats of a fresh page
        # runs over the page: first on the page it had to take something.
        def over?(head, remaining) = floats_above? && measure(head) > remaining + EPSILON

        # Whether a child that does not fit below the floats of a fresh page
        # leaves them for the next page. One taller than the page by itself
        # and in one piece stays with them, and is reported.
        def leaves?(child)
          floats_above? && (may_split?(child) || child.measure(child.width_in(@width)) <= @height + EPSILON)
        end

        def floats_above? = !@placement.nil? && top? && !@placed.empty?

        def may_split?(child, top: top?)
          !child.avoid_break? && (!child.prefer_whole? || top)
        end

        # Whether nothing but floats is above on a fresh page.
        def top? = @fresh && (@placement ? !@placement.content? : @placed.empty?)

        def measure(child) = @slot ? @slot.measure(child) : child.measure(child.width_in(@width))

        # The child's height, or any height above `limit` when it is taller:
        # a long table then leaves the rows beyond the page unmeasured.
        def within(child, limit)
          @slot ? @slot.measure(child) : child.height_within(child.width_in(@width), limit)
        end

        def cut(child, remaining)
          return @slot.split(child, remaining, fresh: top?) if @slot

          child.split(child.width_in(@width), remaining, fresh: top?)
        end

        # The break before `nodes`. Floats placed last go with them: what
        # wraps beside them is the first of `nodes`. Those of a fresh page
        # with nothing else on it stay: they would come back as they are.
        def move(nodes)
          return [part(@placed), part(nodes)] unless @placement && @placed.last&.float? && !top?

          kept = @placed.reverse.drop_while(&:float?).reverse
          [part(kept), part(@placed.drop(kept.size) + nodes)]
        end

        # Whether any of what follows from `index` would be placed in `height`
        # below other content.
        def starts?(index, height)
          return lands?(@children.drop(index), @placement) if @placement

          start?(@children[index], @children[index].width_in(@width), height)
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
            return false unless fits?(node, slot)
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
