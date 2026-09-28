# frozen_string_literal: true

module Stationery
  module Layout
    class Flow < Node
      # A flow that holds floats, or lies beside some: its children are
      # measured and painted where a Placement puts them.
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
          @children.each do |child|
            next if child.page_break?

            slot = child.float? ? placement.float(child) : placement.slot(child)
            slot.paint(child, canvas, x, y)
            height = slot.measure(child)
            canvas.debug_rect(x + slot.left, y + slot.top, slot.width, height, :flow)
            placement.advance(slot, height) unless child.float?
          end
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
