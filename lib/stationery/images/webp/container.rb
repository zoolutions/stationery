# frozen_string_literal: true

module Stationery
  module Images
    class WebP
      # The RIFF container: finds the lossless bitstream, either the file's
      # only chunk or the image of an extended (VP8X) file, whose colour
      # profile and metadata chunks are skipped. Lossy and animated files
      # are refused by name.
      class Container
        HEADER_BYTES = 12
        ANIMATED = 0x02
        LOSSY = "lossy WebP images are not supported, convert to JPEG, PNG or lossless WebP"
        ANIMATION = "animated WebP images are not supported, convert to JPEG, PNG or lossless WebP"

        # The canvas size of an extended file, nil for a bare bitstream.
        attr_reader :canvas

        def initialize(data)
          @data = data
          @limit = data.unpack1("V", offset: 4) + 8 if data.bytesize >= HEADER_BYTES
          raise UnsupportedImage, "truncated WebP image" if @limit.nil? || @limit > data.bytesize
        end

        # The bytes of the VP8L chunk.
        def bitstream
          pos = HEADER_BYTES
          while pos < @limit
            type, payload = chunk(pos)
            case type
            when "VP8L" then return payload
            when "VP8X" then read_extension(payload)
            when "VP8 ", "ALPH" then raise UnsupportedImage, LOSSY
            when "ANIM", "ANMF" then raise UnsupportedImage, ANIMATION
            end
            pos += 8 + payload.bytesize + (payload.bytesize & 1)
          end
          raise UnsupportedImage, "invalid WebP image: no image data"
        end

        private

        def chunk(pos)
          raise UnsupportedImage, "truncated WebP image" if pos + 8 > @limit

          type, size = @data.unpack("a4V", offset: pos)
          raise UnsupportedImage, "truncated WebP image" if pos + 8 + size > @limit

          [type, @data.byteslice(pos + 8, size)]
        end

        def read_extension(payload)
          raise UnsupportedImage, "invalid WebP image: extended header" if payload.bytesize < 10
          raise UnsupportedImage, ANIMATION if payload.getbyte(0).anybits?(ANIMATED)

          # Width and height less one, 24 bits each.
          @canvas = [4, 7].map { |at| "#{payload.byteslice(at, 3)}\0".unpack1("V") + 1 }
        end
      end
    end
  end
end
