# frozen_string_literal: true

module Stationery
  module Layout
    class Box < Node
      # A box beside floats. One that takes the width it is given is a block
      # as CSS knows it: it keeps the full width of its flow, paints its
      # background, border and shadow across it, and hands the floats to its
      # content (`exclusions:`, from its own top), which wraps beside them and
      # takes the full width below them. The content meets the floats inside
      # the padding: padding that lies under a float is not added to it. The
      # floats beside a box that paints something of its own are painted
      # after it (Flow::Floating), so they sit on top of its background.
      #
      # A box with a width or a height of its own, a rotated or a clipped
      # one, or one that places its content by `valign:`, is a block of the
      # width the floats leave, all the way down.
      module Wrapping
        def wraps? = !sized? && @content.wraps?

        # Whether it paints something of its own under the floats beside it,
        # or wraps a box that does.
        def decorated? = wraps? && (painted? || @content.decorated?)

        private

        def sized?
          !(@width_spec.nil? && @height.nil?) || !@rotate.zero? || @overflow != :visible || @valign != :top
        end

        def painted? = !(@background || @border || @shadow || @link).nil?

        # Where the content goes beside floats, and what they take from it
        # there: measure, split and paint place it by this one slot. nil
        # without floats.
        def beside(width, exclusions)
          return unless exclusions

          top, right, _bottom, left = insets
          Flow::Placement::Slot.new(top:, left:, width: inner_width(width),
                                    exclusions: exclusions.inset(top:, right:, left:), need: nil)
        end

        def content_height(width, exclusions)
          slot = beside(width, exclusions)
          slot ? slot.measure(@content) : @content.measure(inner_width(width))
        end

        def split_content(width, height, fresh, exclusions)
          slot = beside(width, exclusions)
          slot ? slot.split(@content, height, fresh:) : @content.split(inner_width(width), height, fresh:)
        end
      end
    end
  end
end
