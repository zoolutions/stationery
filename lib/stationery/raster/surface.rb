# frozen_string_literal: true

module Stationery
  module Raster
    # The pixels of a page, white to start with: `channels` 8-bit samples a
    # pixel (1 grey, 3 RGB), row after row in one binary String. Spans are
    # painted over it, each pixel blended by its coverage times the opacity
    # (source over, in the samples as they are, as a viewer blends).
    class Surface
      OPAQUE = 0.999

      attr_reader :width, :height, :channels, :data

      def initialize(width, height, channels)
        @width = width
        @height = height
        @channels = channels
        @data = ("\xFF".b * (width * height * channels))
      end

      # Paints `spans` in `color`, `channels` samples from 0 to 255.
      def fill(spans, color, opacity = 1.0)
        run = color.pack("C*")
        spans.each_row do |y, row|
          i = 0
          while i < row.size
            x0 = row[i]
            x1 = row[i + 1]
            alpha = row[i + 2] * opacity
            if alpha >= OPAQUE
              @data.bytesplice(((y * @width) + x0) * @channels, (x1 - x0) * @channels, run * (x1 - x0))
            else
              (x0...x1).each { |x| blend(((y * @width) + x) * @channels, color, alpha) }
            end
            i += 3
          end
        end
      end

      # Paints `spans` in the colour the block answers for each pixel,
      # `[sample, …, alpha]` with alpha from 0 to 1, or nil for none.
      def paint(spans, opacity = 1.0)
        spans.each_row do |y, row|
          i = 0
          while i < row.size
            coverage = row[i + 2] * opacity
            (row[i]...row[i + 1]).each do |x|
              color = yield x, y
              next unless color

              blend(((y * @width) + x) * @channels, color, coverage * color[@channels])
            end
            i += 3
          end
        end
      end

      private

      def blend(offset, color, alpha)
        return if alpha <= 0

        @channels.times do |c|
          below = @data.getbyte(offset + c)
          @data.setbyte(offset + c, (below + ((color[c] - below) * alpha)).round.clamp(0, 255))
        end
      end
    end
  end
end
