# frozen_string_literal: true

require "zlib"

require_relative "webp/container"
require_relative "webp/bit_reader"
require_relative "webp/prefix_code"
require_relative "webp/image_stream"
require_relative "webp/predictor"
require_relative "webp/transforms"
require_relative "webp/lossless"

module Stationery
  module Images
    # A lossless WebP (VP8L), decoded when it is loaded and embedded like a
    # PNG with an alpha channel: RGB as a Flate stream, the alpha in a soft
    # mask when any pixel is not opaque. Lossy and animated WebP are refused.
    class WebP
      attr_reader :width, :height

      def initialize(data)
        container = Container.new(data)
        lossless = Lossless.new(container.bitstream)
        @width = lossless.width
        @height = lossless.height
        if container.canvas && container.canvas != [@width, @height]
          raise UnsupportedImage, "invalid WebP image: canvas and image sizes differ"
        end

        split(lossless.pixels, lossless.alpha?)
      end

      def inspect = "#<#{self.class} #{@width}x#{@height}>"

      # This image scaled down to `width` pixels (a Resampled), memoised per
      # width; the same instance is shared through the image cache.
      def resample(width)
        @resampled ||= {}
        @resampled[width] ||= Resampled.new(pixels, width)
      end

      def build(writer)
        dictionary = Images.xobject(@width, @height, :DeviceRGB, 8).merge(Filter: :FlateDecode)
        if @alpha
          mask = Images.xobject(@width, @height, :DeviceGray, 8).merge(Filter: :FlateDecode)
          dictionary[:SMask] = writer.add(PDF::Stream.new(Zlib::Deflate.deflate(@alpha), mask))
        end
        writer.add(PDF::Stream.new(Zlib::Deflate.deflate(@color), dictionary))
      end

      # The samples as a Pixels, built on every call.
      def pixels
        Pixels.new(width: @width, height: @height, channels: 3, color: rows(@color, @width * 3),
                   alpha: @alpha && rows(@alpha, @width))
      end

      private

      # ARGB pixels as the bytes to embed: three per pixel of colour, and
      # one of alpha unless the image is opaque.
      def split(argb, alpha)
        @color = String.new(capacity: argb.size * 3, encoding: Encoding::BINARY)
        argb.each { |pixel| @color << ((pixel >> 16) & 0xFF) << ((pixel >> 8) & 0xFF) << (pixel & 0xFF) }
        @alpha = argb.map { |pixel| pixel >> 24 }.pack("C*") if alpha && argb.any? { |pixel| pixel < 0xFF000000 }
      end

      def rows(bytes, stride)
        Array.new(@height) { |y| bytes.byteslice(y * stride, stride).bytes }
      end
    end
  end
end
