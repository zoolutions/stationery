# frozen_string_literal: true

module Stationery
  module Layout
    class Flow < Node
      # A flow that holds floats, or lies beside some: its children are
      # measured and painted where a Placement puts them. When a child that
      # wraps beside the floats paints something of its own (`decorated?`),
      # the floats are painted after the other children, so that they sit on
      # top of its background; a tagged PDF still reads them where they were
      # written (Floated#reserve). Otherwise every child is painted in the
      # order it was written, as it always was.
      module Floating
        def floats?
          @floats = @children.any?(&:float?) if @floats.nil?
          @floats
        end

        private

        def measure_beside(width, exclusions)
          memoize_by_width(exclusions ? [width, exclusions] : width) do
            placement = Placement.new(self, width, exclusions)
            @children.each do |child|
              next if child.page_break?
              next placement.float(child) if child.float?

              slot = placement.slot(child)
              placement.advance(slot, slot.measure(child))
            end
            placement.height
          end
        end

        def paint_beside(canvas, x, y, width, exclusions)
          placement = Placement.new(self, width, exclusions)
          later = [] if decorated?
          @children.each do |child|
            next if child.page_break?

            slot = child.float? ? placement.float(child) : placement.slot(child)
            if later && child.float?
              child.reserve(canvas)
              later << [child, slot]
            else
              height = paint_placed(canvas, child, slot, x, y)
              placement.advance(slot, height) unless child.float?
            end
          end
          later&.each { |child, slot| paint_placed(canvas, child, slot, x, y) }
        end

        # Paints a child in its slot and answers its height there.
        def paint_placed(canvas, child, slot, x, y)
          slot.paint(child, canvas, x, y)
          height = slot.measure(child)
          canvas.debug_rect(x + slot.left, y + slot.top, slot.width, height, :flow)
          height
        end

        # Floats side by side with the widest of what wraps beside them.
        def natural_width_beside
          floats, others = @children.partition(&:float?)
          floats.sum(&:natural_width) + (others.map(&:natural_width).max || 0)
        end
      end
    end
  end
end
