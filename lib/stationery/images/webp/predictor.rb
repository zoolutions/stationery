# frozen_string_literal: true

module Stationery
  module Images
    class WebP
      # Reverses the predictor transform: every pixel is stored as its
      # difference from a prediction made of its left (L), top (T), top-left
      # (TL) and top-right (TR) neighbours, the mode chosen per block. All
      # arithmetic is per channel, modulo 256, on packed ARGB Integers.
      module Predictor
        BLACK = 0xFF000000
        ODD = 0xFF00FF00
        EVEN = 0x00FF00FF
        # Clears each channel's lowest bit, so halving cannot borrow from
        # the channel above.
        HALVES = 0xFEFEFEFE

        module_function

        def inverse(argb, width, height, bits, modes)
          first_row(argb, width)
          blocks_wide = ImageStream.subsample(width, bits)
          (1...height).each do |y|
            row = y * width
            argb[row] = add(argb[row], argb[row - width])
            column = 1
            while column < width
              mode = (modes[((y >> bits) * blocks_wide) + (column >> bits)] >> 8) & 0xF
              stop = [((column >> bits) + 1) << bits, width].min
              run(mode, argb, row + column, row + stop, width)
              column = stop
            end
          end
          argb
        end

        # The top-left pixel is predicted black, the rest of the row from the left.
        def first_row(argb, width)
          argb[0] = add(argb[0], BLACK)
          (1...width).each { |x| argb[x] = add(argb[x], argb[x - 1]) }
        end

        def run(mode, argb, pos, stop, width)
          while pos < stop
            argb[pos] = add(argb[pos], predict(mode, argb, pos, width))
            pos += 1
          end
        end

        # rubocop:disable-next Metrics/AbcSize -- one branch per mode of the format, run per pixel
        def predict(mode, argb, pos, width)
          top = pos - width
          case mode
          when 1 then argb[pos - 1]
          when 2 then argb[top]
          when 3 then argb[top + 1]
          when 4 then argb[top - 1]
          when 5 then average(average(argb[pos - 1], argb[top + 1]), argb[top])
          when 6 then average(argb[pos - 1], argb[top - 1])
          when 7 then average(argb[pos - 1], argb[top])
          when 8 then average(argb[top - 1], argb[top])
          when 9 then average(argb[top], argb[top + 1])
          when 10 then average(average(argb[pos - 1], argb[top - 1]), average(argb[top], argb[top + 1]))
          when 11 then select(argb[pos - 1], argb[top], argb[top - 1])
          when 12 then Gradient.full(argb[pos - 1], argb[top], argb[top - 1])
          when 13 then Gradient.half(average(argb[pos - 1], argb[top]), argb[top - 1])
          else BLACK # mode 0, and 14 and 15 which the format leaves unused
          end
        end

        def add(a, b)
          (((a & ODD) + (b & ODD)) & ODD) | (((a & EVEN) + (b & EVEN)) & EVEN)
        end

        def average(a, b)
          (((a ^ b) & HALVES) >> 1) + (a & b)
        end

        # Left or top, whichever is nearer to the gradient L + T - TL.
        def select(left, top, top_left)
          distance(top, top_left) < distance(left, top_left) ? left : top
        end

        def distance(a, b)
          ((a >> 24) - (b >> 24)).abs + (((a >> 16) & 0xFF) - ((b >> 16) & 0xFF)).abs +
            (((a >> 8) & 0xFF) - ((b >> 8) & 0xFF)).abs + ((a & 0xFF) - (b & 0xFF)).abs
        end

        # Modes 12 and 13: the gradient of the neighbours, clamped per channel.
        module Gradient
          module_function

          def full(left, top, top_left)
            (clamp((left >> 24) + (top >> 24) - (top_left >> 24)) << 24) |
              (clamp(((left >> 16) & 0xFF) + ((top >> 16) & 0xFF) - ((top_left >> 16) & 0xFF)) << 16) |
              (clamp(((left >> 8) & 0xFF) + ((top >> 8) & 0xFF) - ((top_left >> 8) & 0xFF)) << 8) |
              clamp((left & 0xFF) + (top & 0xFF) - (top_left & 0xFF))
          end

          def half(average, top_left)
            (step(average >> 24, top_left >> 24) << 24) |
              (step((average >> 16) & 0xFF, (top_left >> 16) & 0xFF) << 16) |
              (step((average >> 8) & 0xFF, (top_left >> 8) & 0xFF) << 8) |
              step(average & 0xFF, top_left & 0xFF)
          end

          # a + (a - b) / 2, the division rounding towards zero.
          def step(a, b)
            delta = a - b
            clamp(a + (delta.negative? ? -(-delta >> 1) : delta >> 1))
          end

          def clamp(value) = value.clamp(0, 255)
        end
      end
    end
  end
end
