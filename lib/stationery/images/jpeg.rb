# frozen_string_literal: true

module Stationery
  module Images
    # A JPEG passed through to the viewer as DCTDecode; only the frame header
    # is read, for dimensions and colour components.
    class JPEG
      START_OF_FRAME = [0xC0..0xC3, 0xC5..0xC7, 0xC9..0xCB, 0xCD..0xCF].freeze
      COLOR_SPACES = { 1 => :DeviceGray, 3 => :DeviceRGB, 4 => :DeviceCMYK }.freeze

      attr_reader :width, :height

      def initialize(data)
        @data = data
        read_frame_header
        raise UnsupportedImage, "invalid JPEG image" unless @width
        return if COLOR_SPACES.key?(@components)

        raise UnsupportedImage,
              "unsupported JPEG colour components: #{@components}"
      end

      def build(writer)
        dictionary = Images.xobject(@width, @height, COLOR_SPACES.fetch(@components), @bits).merge(Filter: :DCTDecode)
        # Adobe CMYK JPEGs store inverted values.
        dictionary[:Decode] = [1, 0] * 4 if @components == 4 && @adobe
        writer.add(PDF::Stream.new(@data, dictionary))
      end

      private

      def read_frame_header
        pos = 2
        while pos + 4 <= @data.bytesize
          raise UnsupportedImage, "invalid JPEG image" unless @data.getbyte(pos) == 0xFF

          marker = @data.getbyte(pos + 1)
          next pos += 1 if marker == 0xFF # fill byte

          @adobe = true if marker == 0xEE && @data.byteslice(pos + 4, 5) == "Adobe"
          if START_OF_FRAME.any? { |range| range.cover?(marker) }
            @bits, @height, @width, @components = @data.byteslice(pos + 4, 6).unpack("CnnC")
            return
          end

          pos += 2 + @data.byteslice(pos + 2, 2).unpack1("n")
        end
      end
    end
  end
end
