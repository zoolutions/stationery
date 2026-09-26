# frozen_string_literal: true

require "zlib"

module Stationery
  module Images
    # Inflates PNG image data and reverses the per-row filters, yielding each
    # row as an Array of bytes.
    module Scanlines
      module_function

      def each(idat, height, bpp, row_bytes)
        data = Zlib::Inflate.inflate(idat)
        previous = Array.new(row_bytes, 0)

        height.times do |y|
          pos = y * (row_bytes + 1)
          row = unfilter(data.getbyte(pos), data.byteslice(pos + 1, row_bytes).bytes, previous, bpp)
          yield row
          previous = row
        end
      end

      def unfilter(filter, row, previous, bpp)
        case filter
        when 0 then row
        when 1 then row.each_index { |i| row[i] = (row[i] + (i >= bpp ? row[i - bpp] : 0)) & 0xFF }
        when 2 then row.each_index { |i| row[i] = (row[i] + previous[i]) & 0xFF }
        when 3 then row.each_index do |i|
          row[i] = (row[i] + (((i >= bpp ? row[i - bpp] : 0) + previous[i]) >> 1)) & 0xFF
        end
        when 4 then paeth(row, previous, bpp)
        else raise UnsupportedImage, "invalid PNG filter type: #{filter}"
        end
      end

      def paeth(row, previous, bpp)
        row.each_index do |i|
          a = i >= bpp ? row[i - bpp] : 0
          c = i >= bpp ? previous[i - bpp] : 0
          row[i] = (row[i] + predictor(a, previous[i], c)) & 0xFF
        end
      end

      def predictor(a, b, c)
        p = a + b - c
        pa = (p - a).abs
        pb = (p - b).abs
        pc = (p - c).abs
        return a if pa <= pb && pa <= pc

        pb <= pc ? b : c
      end
    end
  end
end
