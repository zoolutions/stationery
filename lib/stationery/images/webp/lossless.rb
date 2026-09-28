# frozen_string_literal: true

module Stationery
  module Images
    class WebP
      # A VP8L bitstream (WebP Lossless Bitstream Specification): the header
      # is read on creation, `pixels` decodes the image to an Array of ARGB
      # Integers, row by row from the top left.
      class Lossless
        SIGNATURE = 0x2F
        HEADER_BYTES = 5
        # What one image may decode to; the format itself allows 16384 a
        # side, which no page needs and an Array of pixels cannot hold cheaply.
        MAX_PIXELS = 1 << 25
        PREDICTOR = 0
        CROSS_COLOR = 1
        SUBTRACT_GREEN = 2

        attr_reader :width, :height

        def initialize(data)
          raise UnsupportedImage, "truncated WebP image" if data.bytesize < HEADER_BYTES

          @reader = BitReader.new(data)
          raise UnsupportedImage, "invalid WebP image: not a lossless bitstream" unless @reader.read(8) == SIGNATURE

          @width = @reader.read(14) + 1
          @height = @reader.read(14) + 1
          @alpha = @reader.read(1) == 1
          raise UnsupportedImage, "invalid WebP image: unknown lossless version" unless @reader.read(3).zero?
          return if @width * @height <= MAX_PIXELS

          raise UnsupportedImage, "WebP image too large: #{@width}x#{@height} pixels"
        end

        # Whether the alpha channel means anything; when not, every pixel is opaque.
        def alpha? = @alpha

        def pixels
          transforms = read_transforms
          argb = ImageStream.decode(@reader, @coded_width, @height, top: true)
          raise UnsupportedImage, "truncated WebP image" if @reader.overrun?

          transforms.reverse_each { |transform| argb = transform.call(argb) }
          argb
        rescue UnsupportedImage
          raise unless @reader.overrun?

          raise UnsupportedImage, "truncated WebP image"
        end

        private

        # The transforms in the order they were applied, each as a callable
        # that undoes it. A transform may appear once.
        def read_transforms
          @coded_width = @width
          seen = []
          transforms = []
          while @reader.read(1) == 1
            type = @reader.read(2)
            raise UnsupportedImage, "invalid WebP image: transform used twice" if seen.include?(type)

            seen << type
            transforms << read_transform(type)
          end
          transforms
        end

        def read_transform(type)
          width = @coded_width
          case type
          when PREDICTOR
            bits, image = read_blocks(width)
            ->(argb) { Predictor.inverse(argb, width, @height, bits, image) }
          when CROSS_COLOR
            bits, image = read_blocks(width)
            ->(argb) { Transforms.cross_color(argb, width, @height, bits, image) }
          when SUBTRACT_GREEN then Transforms.method(:add_green)
          else read_color_indexing(width)
          end
        end

        # An image of one value per block of 2**bits pixels a side.
        def read_blocks(width)
          bits = @reader.read(3) + 2
          [bits, ImageStream.decode(@reader, ImageStream.subsample(width, bits),
                                    ImageStream.subsample(@height, bits))]
        end

        def read_color_indexing(width)
          size = @reader.read(8) + 1
          table = Transforms.color_table(ImageStream.decode(@reader, size, 1))
          bits = Transforms.bundling(size)
          @coded_width = ImageStream.subsample(width, bits)
          ->(argb) { Transforms.color_indexing(argb, width, @height, bits, table) }
        end
      end
    end
  end
end
