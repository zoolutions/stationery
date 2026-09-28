# frozen_string_literal: true

module Stationery
  module SVG
    # What an element is clipped to: the outlines of `parts`, joined into one
    # clipping path (even-odd when `even_odd`), inside the `outer` region when
    # there is one. A region without parts has nothing inside it.
    Region = Data.define(:parts, :even_odd, :outer) do
      def empty? = parts.empty?
    end

    class Region
      # One outline: anything that traces itself on a path (`trace(path)`),
      # under the transform it is drawn with.
      Part = Data.define(:matrix, :shape)

      # A shape element as a part's outline.
      Shape = Data.define(:element) do
        def trace(path) = Shapes.trace(path, element)
      end

      EMPTY = new([], false, nil).freeze
    end
  end
end
