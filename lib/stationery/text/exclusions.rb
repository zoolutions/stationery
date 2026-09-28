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

      # What is left of them inside a rectangle that starts `top` further
      # down and lies `left` and `right` in from the edges (the content of a
      # box, inside its padding and border); nil when that is nothing.
      def inset(top:, right:, left:)
        Exclusions.of(bands.filter_map do |band|
          inner = band.with(top: [band.top - top, 0].max, bottom: band.bottom - top,
                            left: [band.left - left, 0].max, right: [band.right - right, 0].max)
          inner if inner.bottom > Exclusions::EPSILON && (inner.left.positive? || inner.right.positive?)
        end)
      end
    end

    class Exclusions
      EPSILON = 0.0001
      Band = Data.define(:top, :bottom, :left, :right)
    end
  end
end
