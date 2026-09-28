# frozen_string_literal: true

require_relative "jpeg/huffman"
require_relative "jpeg/bit_reader"
require_relative "jpeg/idct"
require_relative "jpeg/reduced_idct"
require_relative "jpeg/decoder"
require_relative "jpeg/progressive"
require_relative "jpeg/scan"
require_relative "jpeg/upsampler"
require_relative "jpeg/colors"

module Stationery
  module Images
    # A JPEG passed through to the viewer as DCTDecode; only the frame header
    # is read, for dimensions and colour components. Its pixels are decoded
    # only when something needs them (a picture, a monochrome bitmap), once
    # per scale (see #pixels).
    class JPEG
      START_OF_FRAME = [0xC0..0xC3, 0xC5..0xC7, 0xC9..0xCB, 0xCD..0xCF].freeze
      COLOR_SPACES = { 1 => :DeviceGray, 3 => :DeviceRGB, 4 => :DeviceCMYK }.freeze
      # The most pixels decoded, as for a WebP.
      MAX_PIXELS = 1 << 25
      # Fractions of its size a JPEG decodes at, smallest first.
      SCALES = [8, 4, 2].freeze

      attr_reader :width, :height

      # Why a frame of `marker` and `precision` bits is not decoded.
      def self.unsupported_reason(marker, precision)
        return "lossless JPEG images are not decoded" if [0xC3, 0xC7, 0xCB, 0xCF].include?(marker)
        return "hierarchical JPEG images are not decoded" if [0xC5, 0xC6, 0xCD, 0xCE].include?(marker)
        return "arithmetic-coded JPEG images are not decoded" if marker >= 0xC9

        "#{precision}-bit JPEG images are not decoded" unless precision == 8
      end

      def initialize(data)
        @data = data
        read_frame_header
        raise UnsupportedImage, "invalid JPEG image" unless @width
        return if COLOR_SPACES.key?(@components)

        raise UnsupportedImage,
              "unsupported JPEG colour components: #{@components}"
      end

      def inspect = "#<#{self.class} #{@width}x#{@height}>"
      def color_space = COLOR_SPACES.fetch(@components)

      def build(writer)
        dictionary = Images.xobject(@width, @height, color_space, @bits).merge(Filter: :DCTDecode)
        # Adobe CMYK JPEGs store inverted values.
        dictionary[:Decode] = [1, 0] * 4 if @components == 4 && @adobe
        writer.add(PDF::Stream.new(@data, dictionary))
      end

      # Why this JPEG's pixels cannot be decoded (a lossless, arithmetic-coded
      # or 12-bit one, or one of more than MAX_PIXELS), nil when they can.
      def unsupported
        return "a JPEG of more than #{MAX_PIXELS} pixels is not decoded" if @width * @height > MAX_PIXELS

        JPEG.unsupported_reason(@marker, @bits)
      end

      # The samples as a Pixels (grey or RGB, 8 bits, CMYK turned into RGB).
      # With `at_least:` [width, height] in pixels, decoded at the smallest
      # of a half, a quarter or an eighth of its size that is still that
      # large (libjpeg's scaled IDCT: far less work for a photo drawn
      # small), else at full size. Each scale is decoded once and kept; the
      # rows are built on every call.
      def pixels(at_least: nil)
        reason = unsupported
        raise UnsupportedImage, reason if reason

        scale = (at_least && SCALES.find { |s| large_enough?(s, *at_least) }) || 1
        @decoded ||= {}
        samples, channels = @decoded[scale] ||= Colors.call(Decoder.new(@data, scale).call)
        width = (@width + scale - 1) / scale
        height = (@height + scale - 1) / scale
        stride = width * channels
        Pixels.new(width:, height:, channels:, alpha: nil,
                   color: Array.new(height) { |y| samples.byteslice(y * stride, stride).bytes })
      end

      private

      def large_enough?(scale, width, height)
        ((@width + scale - 1) / scale) >= width && ((@height + scale - 1) / scale) >= height
      end

      def read_frame_header
        pos = 2
        while pos + 4 <= @data.bytesize
          raise UnsupportedImage, "invalid JPEG image" unless @data.getbyte(pos) == 0xFF

          marker = @data.getbyte(pos + 1)
          next pos += 1 if marker == 0xFF # fill byte

          @adobe = true if marker == 0xEE && @data.byteslice(pos + 4, 5) == "Adobe"
          if START_OF_FRAME.any? { |range| range.cover?(marker) }
            @marker = marker
            @bits, @height, @width, @components = @data.byteslice(pos + 4, 6).unpack("CnnC")
            return
          end

          pos += 2 + @data.byteslice(pos + 2, 2).unpack1("n")
        end
      end
    end
  end
end
