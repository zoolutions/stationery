# frozen_string_literal: true

module Stationery
  module Text
    # The room floats take from the lines beside them: bands from `top` to
    # `bottom` below the top of whatever is laid out (a paragraph, a flow),
    # each taking `left` points from the left edge and `right` from the right.
    # Compared by its bands, so a paragraph wrapped around the same floats is
    # wrapped once.
    Exclusions = Data.define(:bands) do
      def self.of(bands) = bands.empty? ? nil : new(bands)

      # [left, right]: what a line from `top` to `top + height` gives up on
      # each side; a band it only touches takes nothing.
      def insets(top, height)
        left = right = 0
        bands.each do |band|
          next unless band.top < top + height - Exclusions::EPSILON && band.bottom > top + Exclusions::EPSILON

          left = band.left if band.left > left
          right = band.right if band.right > right
        end
        [left, right]
      end
    end

    class Exclusions
      EPSILON = 0.0001
      Band = Data.define(:top, :bottom, :left, :right)
    end
  end
end
