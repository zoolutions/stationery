# frozen_string_literal: true

require "zlib"

module Stationery
  module Monochrome
    # A bitmap as a one-bit printer prints it: greyed (BT.601 luma, a
    # transparent pixel as white paper), resampled to `width` × `height`
    # dots (the average of the source pixels a dot covers, or the nearest one
    # when there are fewer pixels than dots) and dithered to one bit. Embedded
    # as a DeviceGray image of one bit per component.
    class Bitmap
      attr_reader :width, :height

      # `pixels` is an Images::Pixels.
      def initialize(pixels, width, height, dither)
        @width = [width, 1].max
        @height = [height, 1].max
        @bits = Dither.call(resample(grey(pixels), pixels.width, pixels.height), @width, @height, dither)
      end

      def inspect = "#<#{self.class} #{@width}x#{@height}>"

      # The dots as Images::Pixels, 0 (black) or 255 each, for a canvas that
      # draws them itself (Raster::Canvas).
      def pixels
        stride = (@width + 7) / 8
        rows = Array.new(@height) do |y|
          @bits.byteslice(y * stride, stride).unpack1("B*")[0, @width].each_char.map { |bit| bit == "1" ? 255 : 0 }
        end
        Images::Pixels.new(width: @width, height: @height, channels: 1, color: rows, alpha: nil)
      end

      def build(writer)
        dictionary = Images.xobject(@width, @height, :DeviceGray, 1).merge(Filter: :FlateDecode)
        writer.add(PDF::Stream.new(Zlib::Deflate.deflate(@bits), dictionary))
      end

      private

      # One row of grey samples per source row.
      def grey(pixels)
        pixels.color.each_with_index.map do |row, y|
          alpha = pixels.alpha&.[](y)
          values = if pixels.channels == 1
                     row
                   else
                     row.each_slice(3).map { |r, g, b| ((299 * r) + (587 * g) + (114 * b)) / 1000 }
                   end
          alpha ? values.each_with_index.map { |v, x| 255 - ((255 - v) * alpha[x] / 255) } : values
        end
      end

      def resample(rows, source_width, source_height)
        columns = spans(source_width, @width)
        out = String.new(capacity: @width * @height, encoding: Encoding::BINARY)
        spans(source_height, @height).each do |y0, y1|
          sums = Array.new(@width, 0)
          (y0...y1).each do |y|
            row = rows[y]
            columns.each_with_index { |(x0, x1), ox| (x0...x1).each { |x| sums[ox] += row[x] } }
          end
          columns.each_with_index { |(x0, x1), ox| out << (sums[ox] / ((x1 - x0) * (y1 - y0))) }
        end
        out
      end

      # [start, end) source indexes for each of `target` positions: the block
      # a dot covers, one pixel at least.
      def spans(source, target)
        Array.new(target) do |i|
          first = [(i * source) / target, source - 1].min
          [first, [((i + 1) * source) / target, first + 1].max]
        end
      end
    end
  end
end
