# frozen_string_literal: true

require "zlib"

module Stationery
  module Images
    # A PNG. Opaque images pass their compressed data straight through with a
    # PNG predictor; transparency is split into a soft mask (or a colour-key
    # mask for grey/RGB tRNS).
    class PNG
      CHANNELS = { 0 => 1, 2 => 3, 3 => 1, 4 => 2, 6 => 4 }.freeze

      attr_reader :width, :height

      def initialize(data)
        @idat = String.new(encoding: Encoding::BINARY)
        read_chunks(data)
        raise UnsupportedImage, "invalid PNG image" unless @width && CHANNELS.key?(@color_type)
        raise UnsupportedImage, "interlaced PNG images are not supported, save it non-interlaced" if @interlace == 1
      end

      def inspect = "#<#{self.class} #{@width}x#{@height}>"

      def build(writer)
        return build_with_alpha(writer) if alpha_channel?

        dictionary = Images.xobject(@width, @height, color_space, @bit_depth).merge(
          Filter: :FlateDecode,
          DecodeParms: { Predictor: 15, Colors: CHANNELS[@color_type], BitsPerComponent: @bit_depth, Columns: @width }
        )
        if @transparency && @color_type == 3
          dictionary[:SMask] = soft_mask(writer, palette_alpha)
        elsif @transparency
          dictionary[:Mask] = @transparency.unpack("n*").first(CHANNELS[@color_type]).flat_map { |v| [v, v] }
        end
        writer.add(PDF::Stream.new(@idat, dictionary))
      end

      private

      def read_chunks(data)
        pos = PNG_SIGNATURE.bytesize
        while pos + 8 <= data.bytesize
          length, type = data.byteslice(pos, 8).unpack("Na4")
          chunk = data.byteslice(pos + 8, length)
          break if type == "IEND"

          read_chunk(type, chunk)
          pos += 12 + length
        end
      end

      def read_chunk(type, chunk)
        case type
        when "IHDR" then @width, @height, @bit_depth, @color_type, _, _, @interlace = chunk.unpack("NNCCCCC")
        when "PLTE" then @palette = chunk
        when "tRNS" then @transparency = chunk
        when "IDAT" then @idat << chunk
        end
      end

      def alpha_channel?
        [4, 6].include?(@color_type)
      end

      def build_with_alpha(writer)
        color, alpha = split_alpha
        dictionary = Images.xobject(@width, @height, color_space, 8)
                           .merge(Filter: :FlateDecode, SMask: soft_mask(writer, alpha))
        writer.add(PDF::Stream.new(Zlib::Deflate.deflate(color), dictionary))
      end

      def color_space
        case @color_type
        when 0, 4 then :DeviceGray
        when 2, 6 then :DeviceRGB
        else [:Indexed, :DeviceRGB, (@palette.bytesize / 3) - 1, PDF::HexString.new(@palette)]
        end
      end

      def soft_mask(writer, alpha)
        dictionary = Images.xobject(@width, @height, :DeviceGray, 8).merge(Filter: :FlateDecode)
        writer.add(PDF::Stream.new(Zlib::Deflate.deflate(alpha), dictionary))
      end

      def palette_alpha
        alphas = @transparency.bytes
        alpha = String.new(capacity: @width * @height, encoding: Encoding::BINARY)
        Scanlines.each(@idat, @height, 1, ((@width * @bit_depth) + 7) / 8) do |row|
          alpha << palette_indexes(row).map { |index| alphas[index] || 255 }.pack("C*")
        end
        alpha
      end

      def palette_indexes(row)
        return row if @bit_depth == 8

        row.pack("C*").unpack1("B*").scan(/.{#{@bit_depth}}/o).first(@width).map { |bits| bits.to_i(2) }
      end

      # Grey+alpha or RGBA pixels split into colour and alpha, 8 bits per sample.
      def split_alpha
        channels = CHANNELS[@color_type]
        sample = @bit_depth / 8
        step = channels * sample
        color_bytes = Array.new(@width) { |x| Array.new(channels - 1) { |c| (x * step) + (c * sample) } }.flatten
        alpha_bytes = Array.new(@width) { |x| (x * step) + ((channels - 1) * sample) }

        color = String.new(encoding: Encoding::BINARY)
        alpha = String.new(encoding: Encoding::BINARY)
        Scanlines.each(@idat, @height, step, @width * step) do |row|
          color << row.values_at(*color_bytes).pack("C*")
          alpha << row.values_at(*alpha_bytes).pack("C*")
        end
        [color, alpha]
      end
    end
  end
end
