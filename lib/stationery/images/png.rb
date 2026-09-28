# frozen_string_literal: true

require "zlib"

module Stationery
  module Images
    # A PNG. Opaque images pass their compressed data straight through with a
    # PNG predictor; transparency is split into a soft mask (or a colour-key
    # mask for grey/RGB tRNS).
    class PNG
      CHANNELS = { 0 => 1, 2 => 3, 3 => 1, 4 => 2, 6 => 4 }.freeze
      # Colour samples per pixel once palette and alpha are unpacked.
      COLOR_CHANNELS = { 0 => 1, 2 => 3, 3 => 3, 4 => 1, 6 => 3 }.freeze

      attr_reader :width, :height

      def initialize(data)
        @idat = String.new(encoding: Encoding::BINARY)
        read_chunks(data)
        raise UnsupportedImage, "invalid PNG image" unless @width && CHANNELS.key?(@color_type)
        raise UnsupportedImage, "interlaced PNG images are not supported, save it non-interlaced" if @interlace == 1
      end

      def inspect = "#<#{self.class} #{@width}x#{@height}>"

      # This image scaled down to `width` pixels (a Resampled), memoised per
      # width; the same instance is shared through the image cache.
      def resample(width)
        @resampled ||= {}
        @resampled[width] ||= Resampled.new(pixels, width)
      end

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

      # Every sample as 8 bits (a Pixels), colour rows apart from alpha rows:
      # palette and sub-byte greys expanded, 16-bit samples dropped to their
      # high byte, a colour-key or palette transparency turned into an alpha
      # row set. Decoded on every call.
      def pixels
        channels = CHANNELS[@color_type]
        color = []
        alpha = []
        Scanlines.each(@idat, @height, [(channels * @bit_depth) / 8, 1].max,
                       ((@width * channels * @bit_depth) + 7) / 8) do |row|
          samples = samples_of(row)
          case @color_type
          when 3 then palette_pixels(samples, color, alpha)
          when 4, 6 then split_pixels(samples, channels, color, alpha)
          else keyed_pixels(samples, channels, color, alpha)
          end
        end
        Pixels.new(width: @width, height: @height, channels: COLOR_CHANNELS[@color_type],
                   color:, alpha: alpha.empty? ? nil : alpha)
      end

      private

      # A row's samples at 8 bits.
      def samples_of(row)
        case @bit_depth
        when 8 then row
        when 16 then row.each_slice(2).map(&:first)
        else
          scale = 255 / ((1 << @bit_depth) - 1)
          bits = row.pack("C*").unpack1("B*")
          values = bits.scan(/.{#{@bit_depth}}/o).first(@width).map { |b| b.to_i(2) }
          @color_type == 3 ? values : values.map { |v| v * scale }
        end
      end

      def palette_pixels(indexes, color, alpha)
        palette = @palette.bytes
        alphas = @transparency&.bytes
        color << indexes.flat_map { |i| palette[i * 3, 3] }
        alpha << indexes.map { |i| alphas[i] || 255 } if alphas
      end

      def split_pixels(samples, channels, color, alpha)
        color << samples.each_slice(channels).flat_map { |px| px[0...-1] }
        alpha << samples.each_slice(channels).map(&:last)
      end

      # Grey or RGB, with a tRNS colour key (compared at the file's bit depth)
      # becoming a fully transparent alpha.
      def keyed_pixels(samples, channels, color, alpha)
        color << samples
        return unless @transparency

        key = @transparency.unpack("n*").first(channels).map do |v|
          @bit_depth == 16 ? v >> 8 : v * (255 / ((1 << @bit_depth) - 1))
        end
        alpha << samples.each_slice(channels).map { |px| px == key ? 0 : 255 }
      end

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
