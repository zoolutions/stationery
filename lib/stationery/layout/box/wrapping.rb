# frozen_string_literal: true

module Stationery
  module Layout
    class Box < Node
      # A box beside floats. One that paints nothing of its own and takes the
      # width it is given is a block as CSS knows it: it keeps the full width
      # of its flow and hands the floats to its content (`exclusions:`, from
      # its own top), which wraps beside them and takes the full width below
      # them. The content meets the floats inside the padding: padding that
      # lies under a float is not added to it.
      #
      # Any other box is a block of the width the floats leave, all the way
      # down: one with a background, a border, a shadow or a link, which
      # would be painted over a float that was painted before it, and one
      # with a width or a height of its own, a rotated or a clipped one, or
      # one that places its content by `valign:`.
      module Wrapping
        def wraps? = !sized? && !painted? && @content.wraps?

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
                                    exclusions: exclusions.inset(top:, right:, left:))
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
