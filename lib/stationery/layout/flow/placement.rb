# frozen_string_literal: true

module Stationery
  module Layout
    class Flow < Node
      # Where the children of a flow that holds floats (or lies beside some:
      # `exclusions`) go. Measuring, painting and splitting all walk the
      # children through one of these, so they place them alike.
      #
      # A float goes to its side at the top the next child will have: beside
      # the floats already there when it fits, else below them, and never
      # above a float placed before it. It takes no height of its own; the
      # flow is as tall as its lowest float.
      #
      # A child that wraps (text, a nested flow, a list item, a box that
      # paints nothing of its own) keeps the full width and is given the
      # floats beside it as exclusions. It moves below the floats that
      # leave less than its `min_width`. Any other child is a block
      # beside the floats: it gets the width left between every float still
      # beside or below its top, all the way down, when its own width (or its
      # `min_width`) fits there, else it moves below them.
      class Placement
        Band = ::Stationery::Text::Exclusions::Band

        # Where one child goes: `top` and `left` from the flow's top left
        # corner, the `width` it is laid out at and, for one that wraps, the
        # floats beside it.
        Slot = Data.define(:top, :left, :width, :exclusions) do
          def measure(node) = exclusions ? node.measure(width, exclusions:) : node.measure(width)

          def split(node, height, fresh:)
            exclusions ? node.split(width, height, fresh:, exclusions:) : node.split(width, height, fresh:)
          end

          def paint(node, canvas, x, y)
            return node.paint(canvas, x + left, y + top, width, exclusions:) if exclusions

            node.paint(canvas, x + left, y + top, width)
          end
        end

        def initialize(flow, width, exclusions = nil)
          @gap = flow.gap
          @align = flow.align
          @width = width
          @bands = exclusions ? exclusions.bands.dup : []
          @cursor = 0
          @lowest = 0
          @floor = 0
          @content = false
        end

        # Whether a child that is not a float has been placed.
        def content? = @content

        # The flow's height so far: its content and its own floats.
        def height = [@cursor, @lowest].max

        def initialize_copy(source)
          super
          @bands = @bands.dup
        end

        # Places a float and remembers the room it takes.
        def float(node)
          width = node.width_in(@width)
          height = node.measure(width)
          top = clear([start, @floor].max) { |y| room(*insets(y, height)) >= width - EPSILON }
          left, right = insets(top, height)
          x = node.side == :left ? left : [@width - right - width, 0].max
          @bands << Band.new(top:, bottom: top + height, left: node.side == :left ? x + width : 0,
                             right: node.side == :left ? 0 : @width - x)
          @floor = top
          @lowest = [@lowest, top + height].max
          Slot.new(top:, left: x, width:, exclusions: nil)
        end

        # The slot of the next child in the flow; `advance` takes it.
        def slot(node)
          return plain(node) if free?(start)

          node.wraps? ? wrapping(node) : block(node)
        end

        def advance(slot, height)
          @cursor = slot.top + height
          @content = true
        end

        private

        def start = @cursor + (@content ? @gap : 0)

        # Below every float: the full width, as in a flow without floats.
        def plain(node)
          own = node.fixed_width(@width)
          left = own ? Geometry.align_offset(@align, @width, own) : 0
          Slot.new(top: start, left:, width: own || @width, exclusions: nil)
        end

        def wrapping(node)
          need = node.min_width
          top = clear(start) { |y| room(*below(y)) >= need - EPSILON }
          Slot.new(top:, left: 0, width: @width, exclusions: exclusions_at(top))
        end

        def block(node)
          fixed = node.fixed_width(@width)
          need = fixed || node.min_width
          top = clear(start) { |y| room(*below(y)) >= need - EPSILON }
          left, right = below(top)
          space = room(left, right)
          width = fixed ? [fixed, space].min : space
          Slot.new(top:, left: left + (fixed ? Geometry.align_offset(@align, space, width) : 0), width:,
                   exclusions: nil)
        end

        # The first top from `from` down that the block takes: `from` itself,
        # else the bottom of a float, the lowest of them when none will do.
        def clear(from, &)
          tops = [from, *@bands.map(&:bottom).select { |bottom| bottom > from }.sort]
          tops.find(&) || tops.last
        end

        def room(left, right) = @width - left - right
        def free?(top) = @bands.none? { |band| band.bottom > top + EPSILON }

        # [left, right] taken by the floats beside a rectangle.
        def insets(top, height)
          sides(@bands.select { |band| band.bottom > top + EPSILON && band.top < top + height - EPSILON })
        end

        # [left, right] taken by every float beside or below `top`.
        def below(top) = sides(@bands.select { |band| band.bottom > top + EPSILON })

        def sides(bands) = [bands.map(&:left).max || 0, bands.map(&:right).max || 0]

        def exclusions_at(top)
          ::Stationery::Text::Exclusions.of(
            @bands.select { |band| band.bottom > top + EPSILON }.map do |band|
              band.with(top: [band.top - top, 0].max, bottom: band.bottom - top)
            end
          )
        end
      end
    end
  end
end
