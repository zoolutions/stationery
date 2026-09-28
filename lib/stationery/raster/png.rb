# frozen_string_literal: true

require "zlib"

module Stationery
  module Raster
    # A PNG file from rows of samples: 8-bit grey (`channels: 1`), 8-bit RGB
    # (`channels: 3`) or one bit per pixel (`depth: 1`, rows packed eight
    # pixels to a byte, most significant bit first, 1 for white). Rows are
    # written unfiltered, which deflate squeezes well enough for pages that
    # are mostly flat colour, and much faster in Ruby than a filter.
    module PNG
      SIGNATURE = "\x89PNG\r\n\x1A\n".b
      NO_FILTER = "\x00".b

      module_function

      def encode(data, width:, height:, channels:, depth: 8)
        stride = depth == 1 ? (width + 7) / 8 : width * channels
        ihdr = [width, height, depth, channels == 1 ? 0 : 2, 0, 0, 0].pack("NNCCCCC")
        raw = String.new(capacity: (stride + 1) * height, encoding: Encoding::BINARY)
        height.times { |y| raw << NO_FILTER << data.byteslice(y * stride, stride) }
        SIGNATURE + chunk("IHDR", ihdr) + chunk("IDAT", Zlib::Deflate.deflate(raw)) + chunk("IEND", "".b)
      end

      def chunk(type, data)
        type = type.b
        [data.bytesize].pack("N") + type + data + [Zlib.crc32(type + data)].pack("N")
      end
    end
  end
end
