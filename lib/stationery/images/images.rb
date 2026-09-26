# frozen_string_literal: true

module Stationery
  # JPEG and PNG images, embedded as image XObjects.
  module Images
    PNG_SIGNATURE = "\x89PNG\r\n\x1A\n".b
    JPEG_SIGNATURE = "\xFF\xD8".b
    UNSUPPORTED = {
      "GIF8" => "GIF", "RIFF" => "WebP", "II*\0" => "TIFF", "MM\0*" => "TIFF", "BM" => "BMP"
    }.freeze

    module_function

    # Accepts a path, a Pathname or an IO-like object (read from its start).
    def load(source)
      data = read(source)
      Cache.fetch(data) { parse(data) }
    end

    def read(source)
      data = if source.respond_to?(:read)
               source.binmode if source.respond_to?(:binmode)
               source.rewind if source.respond_to?(:rewind)
               source.read
             else
               File.binread(source.to_s)
             end
      data.b
    end

    def parse(data)
      return JPEG.new(data) if data.start_with?(JPEG_SIGNATURE)
      return PNG.new(data) if data.start_with?(PNG_SIGNATURE)

      format = UNSUPPORTED.find { |magic, _| data.start_with?(magic.b) }&.last
      raise UnsupportedImage, "#{format} images are not supported, convert to PNG or JPEG" if format

      raise UnsupportedImage, "only PNG and JPEG images are supported"
    end

    def xobject(width, height, color_space, bits)
      { Type: :XObject, Subtype: :Image, Width: width, Height: height, ColorSpace: color_space, BitsPerComponent: bits }
    end
  end
end
