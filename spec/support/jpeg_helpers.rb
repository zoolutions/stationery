# frozen_string_literal: true

# The JPEG fixtures of spec/fixtures/images/jpeg and the pixels libjpeg-turbo
# decodes them to. Written by Pillow 12.3 (ycc420, ycc422_progressive, cmyk,
# one_pixel, scaled, exif_rotated with EXIF orientation 6) and cjpeg
# (libjpeg-turbo 3: the other sampling factors, restart intervals, scans
# scripted one component at a time or by successive approximation, -rgb,
# -quality 3 for an extended frame of 16-bit tables, and the three kinds not
# decoded: -arithmetic, -lossless, -precision 12) from noisy synthetic
# pictures; ycck is cmyk with its Adobe transform set to 2. Each <name>.ppm or
# .pgm is Pillow's decode (RGB, or L for grey), scaled_N.ppm at 1/N through
# Image#draft.
module JpegHelpers
  def jpeg_path(name) = image_path("jpeg/#{name}.jpg")
  def jpeg(name) = Stationery::Images::JPEG.new(File.binread(jpeg_path(name)))

  # [width, height, channels, samples] of a reference PNM.
  def jpeg_reference(name)
    file = %w[ppm pgm].map { |ext| image_path("jpeg/#{name}.#{ext}") }.find { |path| File.exist?(path) }
    data = File.binread(file)
    magic, width, height, _max = data.split(/\s+/, 5).first(4)
    header = data.index("255\n") + 4
    [width.to_i, height.to_i, magic == "P5" ? 1 : 3, data.byteslice(header..).bytes]
  end

  # The largest difference of any sample between `pixels` and the reference.
  def largest_difference(pixels, reference)
    pixels.color.flatten.zip(reference).map { |ours, theirs| (ours - theirs).abs }.max
  end
end

RSpec.configure { |config| config.include JpegHelpers }
