# frozen_string_literal: true

module Stationery
  module Images
    class WebP
      # The subtract-green, cross-colour and colour-indexing transforms,
      # reversed (the predictor has a file of its own). Each takes and
      # returns the image as an Array of ARGB Integers.
      module Transforms
        module_function

        # Green was subtracted from red and blue.
        def add_green(argb)
          argb.map! do |pixel|
            green = (pixel >> 8) & 0xFF
            (pixel & 0xFF00FF00) | (((pixel & 0x00FF00FF) + ((green << 16) | green)) & 0x00FF00FF)
          end
        end

        # Red was predicted from green, blue from green and red, with
        # signed 3.5 fixed-point multipliers stored per block.
        def cross_color(argb, width, height, bits, elements)
          blocks_wide = ImageStream.subsample(width, bits)
          height.times do |y|
            row = y * width
            column = 0
            while column < width
              element = elements[((y >> bits) * blocks_wide) + (column >> bits)]
              stop = [((column >> bits) + 1) << bits, width].min
              recolor(argb, row + column, row + stop, element)
              column = stop
            end
          end
          argb
        end

        def recolor(argb, pos, stop, element)
          green_to_red = signed(element & 0xFF)
          green_to_blue = signed((element >> 8) & 0xFF)
          red_to_blue = signed((element >> 16) & 0xFF)
          while pos < stop
            pixel = argb[pos]
            green = signed((pixel >> 8) & 0xFF)
            red = ((pixel >> 16) + ((green_to_red * green) >> 5)) & 0xFF
            blue = (pixel + ((green_to_blue * green) >> 5) + ((red_to_blue * signed(red)) >> 5)) & 0xFF
            argb[pos] = (pixel & 0xFF00FF00) | (red << 16) | blue
            pos += 1
          end
        end

        def signed(byte) = byte > 127 ? byte - 256 : byte

        # The colour table as stored: every entry is the difference from the
        # one before it. Padded to 256 entries so any index finds a colour
        # (transparent black past the end of the table).
        def color_table(deltas)
          previous = 0
          table = deltas.map { |delta| previous = Predictor.add(delta, previous) }
          table.fill(0, table.size...256)
        end

        # Green holds an index into the colour table, or 2, 4 or 8 of them
        # packed from the lowest bits up when the table is small.
        def color_indexing(argb, width, height, bits, table)
          return argb.map! { |pixel| table[(pixel >> 8) & 0xFF] } if bits.zero?

          packed_width = ImageStream.subsample(width, bits)
          depth = 8 >> bits
          mask = (1 << depth) - 1
          out = Array.new(width * height, 0)
          height.times do |y|
            source = y * packed_width
            row = y * width
            width.times do |x|
              packed = (argb[source + (x >> bits)] >> 8) & 0xFF
              out[row + x] = table[(packed >> ((x & ((1 << bits) - 1)) * depth)) & mask]
            end
          end
          out
        end

        # How many indexes share a pixel for a table of `size` colours, as
        # the power of two.
        def bundling(size)
          return 0 if size > 16
          return 1 if size > 4

          size > 2 ? 2 : 3
        end
      end
    end
  end
end
