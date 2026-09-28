# frozen_string_literal: true

module Stationery
  module Text
    class Wrapper
      # What is left to wrap after the first lines of a paragraph: the text a
      # page break carries over to a place of another width, where it is
      # wrapped again. Found by wrapping as before and stopping after those
      # lines, so a word broken at the stop hands on the part that did not
      # fit, soft hyphens and all.
      module Remainder
        # The runs left after the first `count` lines of `wrap` with the same arguments.
        def rest(runs, max_width, count, **)
          return runs if count.zero?

          @stop = count
          carried = catch(:stopped) do
            wrap(runs, max_width, **)
            return []
          end
          runs_of(carried + @ahead.flat_map { |item| segments_of(item, carried.last || @ahead.first) })
        ensure
          @stop = nil
        end

        private

        def place_all(items)
          return items.each { |item| place(item) } unless @stop

          items.each_with_index do |item, index|
            @ahead = items.drop(index + 1)
            place(item)
          end
        end

        # A newline and a zero-width space are items without a segment; they
        # go on in the style of the text around them.
        def segments_of((kind, segments), neighbour)
          return segments unless kind == :newline || segments.empty?

          [Segment.new(kind == :newline ? "\n" : ZERO_WIDTH_SPACE, style_of(neighbour))]
        end

        def style_of(neighbour)
          return neighbour.style if neighbour.is_a?(Segment)

          neighbour[1]&.first&.style || @fallback
        end

        def runs_of(segments)
          segments.chunk_while { |a, b| a.style == b.style }.map do |group|
            Run.new(group.map(&:text).join, group.first.style)
          end
        end
      end
    end
  end
end
