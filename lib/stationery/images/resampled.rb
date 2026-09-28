# frozen_string_literal: true

require "zlib"

module Stationery
  module Images
    # A decoded image scaled down to a pixel width with a box filter (every
    # source pixel of a block weighs the same), embedded as 8-bit grey or RGB
    # with the alpha, when there is one, in a soft mask. Built by
    # PNG#resample and WebP#resample (a JPEG is embedded as it is, never
    # resampled), and by a raster render for any bitmap it draws smaller.
    class Resampled
      attr_reader :width, :height

      # `pixels` is a Pixels: rows of 8-bit samples, `channels` colour samples
      # per pixel (1 or 3) and an optional alpha row set.
      def initialize(pixels, width)
        @channels = pixels.channels
        @width = [width, 1].max
        @height = [(pixels.height * @width / pixels.width.to_f).round, 1].max
        @color = shrink(pixels.color, pixels.width, pixels.height, @channels)
        @alpha = pixels.alpha && shrink(pixels.alpha, pixels.width, pixels.height, 1)
      end

      def inspect = "#<#{self.class} #{@width}x#{@height}>"

      def build(writer)
        color_space = @channels == 1 ? :DeviceGray : :DeviceRGB
        dictionary = Images.xobject(@width, @height, color_space, 8).merge(Filter: :FlateDecode)
        if @alpha
          mask = Images.xobject(@width, @height, :DeviceGray, 8).merge(Filter: :FlateDecode)
          dictionary[:SMask] = writer.add(PDF::Stream.new(Zlib::Deflate.deflate(@alpha), mask))
        end
        writer.add(PDF::Stream.new(Zlib::Deflate.deflate(@color), dictionary))
      end

      # The resampled samples as a Pixels, built on every call.
      def pixels
        Pixels.new(width: @width, height: @height, channels: @channels, color: rows(@color, @width * @channels),
                   alpha: @alpha && rows(@alpha, @width))
      end

      private

      def rows(bytes, stride) = Array.new(@height) { |y| bytes.byteslice(y * stride, stride).bytes }

      # Box filter: output pixel (ox, oy) averages the source block whose edges
      # are the scaled output edges. Row sums are accumulated per output column
      # first so every source sample is visited once.
      def shrink(rows, source_width, source_height, channels)
        columns = spans(source_width, @width)
        bands = spans(source_height, @height)
        out = String.new(capacity: @width * @height * channels, encoding: Encoding::BINARY)
        bands.each do |y0, y1|
          sums = Array.new(@width * channels, 0)
          (y0...y1).each { |y| add_row(sums, rows[y], columns, channels) }
          count = y1 - y0
          columns.each_with_index do |(x0, x1), ox|
            n = (x1 - x0) * count
            channels.times { |c| out << (sums[(ox * channels) + c] / n) }
          end
        end
        out
      end

      def add_row(sums, row, columns, channels)
        columns.each_with_index do |(x0, x1), ox|
          base = ox * channels
          (x0...x1).each do |x|
            offset = x * channels
            channels.times { |c| sums[base + c] += row[offset + c] }
          end
        end
      end

      # [start, end) source indexes for each of `target` output positions;
      # every source index lands in exactly one span.
      def spans(source, target)
        Array.new(target) do |i|
          [(i * source) / target, (((i + 1) * source) / target).clamp(((i * source) / target) + 1, source)]
        end
      end
    end

    # Decoded PNG or WebP samples: `color` and `alpha` are Arrays of rows, each row an
    # Array of 8-bit sample values (`channels` per pixel for colour, one for alpha).
    Pixels = Data.define(:width, :height, :channels, :color, :alpha)
  end
end
