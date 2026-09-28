# frozen_string_literal: true

module Stationery
  module Images
    class JPEG
      # A component's samples brought to the image's size, one output row at
      # a time (`row(y)`, an Array of `width` samples). Chroma at half the
      # width, the height or both is interpolated with libjpeg's "fancy"
      # triangle filter (jdsample.c: each output sample three quarters its
      # own input sample and a quarter its nearest neighbour, edges repeated,
      # rounded as libjpeg rounds), as libjpeg does by default; any other
      # ratio repeats each sample, as libjpeg does too.
      class Upsampler
        # `in_width` × `in_height` samples of `component`'s plane, spread by
        # the factors to `width` columns.
        def initialize(component, in_width, in_height, width, factors, fancy:)
          @plane = component.plane
          @stride = component.stride
          @in_width = in_width
          @in_height = in_height
          @width = width
          @fx, @fy = factors
          @fancy = fancy && ((@fx == 2 && @fy <= 2 && in_width > 2) || (@fx == 1 && @fy == 2))
          @rows = {}
        end

        def row(y)
          return spread(input(y / @fy)) unless @fancy
          return fancy(input(y), 1, 2, 2) if @fy == 1

          iy = y / 2
          current = input(iy)
          other = input(y.even? ? iy - 1 : iy + 1)
          sums = Array.new(@in_width) { |x| (current[x] * 3) + other[x] }
          return fancy(sums, 8, 7, 4) if @fx == 2

          bias = y.even? ? 1 : 2
          sums.map! { |sum| (sum + bias) >> 2 }
        end

        private

        # The samples of input row `row`, the edge rows repeated beyond the
        # image; the last few are kept while the next output rows need them.
        def input(row)
          row = row.clamp(0, @in_height - 1)
          @rows.shift if @rows.size > 3 && !@rows.key?(row)
          @rows[row] ||= @plane.byteslice(row * @stride, @in_width).bytes
        end

        def spread(samples)
          return samples.first(@width) if @fx == 1

          out = Array.new(@in_width * @fx)
          samples.each_with_index { |sample, x| out.fill(sample, x * @fx, @fx) }
          out.first(@width)
        end

        # Two outputs for each of `values` (samples, or column sums at 4
        # times their scale): three parts of it and one of its left or right
        # neighbour, with libjpeg's rounding, shifted back down by `shift`.
        def fancy(values, left, right, shift)
          last = values.size - 1
          out = Array.new(values.size * 2)
          out[0] = ((values[0] * 4) + left) >> shift
          out[1] = ((values[0] * 3) + values[1] + right) >> shift
          x = 1
          while x < last
            three = values[x] * 3
            out[2 * x] = (three + values[x - 1] + left) >> shift
            out[(2 * x) + 1] = (three + values[x + 1] + right) >> shift
            x += 1
          end
          out[2 * last] = ((values[last] * 3) + values[last - 1] + left) >> shift
          out[(2 * last) + 1] = ((values[last] * 4) + right) >> shift
          out.first(@width)
        end
      end
    end
  end
end
