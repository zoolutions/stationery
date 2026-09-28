# frozen_string_literal: true

require "zlib"

# The WebP fixtures under spec/fixtures/images/webp and the pixels libwebp
# decodes them to. photo, alpha (`-exact`) and palette2/4/16/60 were written
# by `cwebp -lossless -z 9` (libwebp 1.6.0) from ImageMagick plasma and noise
# images, regions by `-z 6` from a photo beside a drawing, extended is
# palette16 with an EXIF chunk from `webpmux -set exif`, lossy_alpha comes
# from `cwebp -q 40` and animated from `img2webp`. predictors (a block per
# predictor mode) and indexed4/9/20 (colour tables of each packing, with indexes past
# the table) were built with WebpFactory, since no encoder writes them.
# Every <name>.png is what `dwebp <name>.webp -o <name>.png` made of the file.
module WebpHelpers
  def webp_path(name) = image_path("webp/#{name}.webp")
  def webp(name) = File.binread(webp_path(name))

  # [width, height, RGB bytes, alpha bytes] of a fixture's reference PNG
  # (8-bit RGB or RGBA).
  def reference(name)
    data = File.binread(image_path("webp/#{name}.png"))
    width, height, _depth, color_type = data.byteslice(16, 10).unpack("NNCC")
    channels = color_type == 6 ? 4 : 3
    samples = []
    Stationery::Images::Scanlines.each(png_data(data), height, channels, width * channels) { |row| samples.concat(row) }
    pixels = samples.each_slice(channels).to_a
    [width, height, pixels.flat_map { |pixel| pixel.first(3) }, pixels.map { |pixel| pixel[3] || 255 }]
  end

  def png_data(data)
    pos = 8
    idat = "".b
    while pos < data.bytesize
      length, type = data.byteslice(pos, 8).unpack("Na4")
      idat << data.byteslice(pos + 8, length) if type == "IDAT"
      pos += 12 + length
    end
    idat
  end

  # [RGB bytes, alpha bytes or nil] as the image embeds them.
  def embedded(image)
    writer = Stationery::PDF::Writer.new
    objects = writer.instance_variable_get(:@objects)
    stream = objects[image.build(writer).id - 1]
    mask = stream.dictionary[:SMask]
    [Zlib::Inflate.inflate(stream.data).bytes, mask && Zlib::Inflate.inflate(objects[mask.id - 1].data).bytes]
  end
end

RSpec.configure { |config| config.include WebpHelpers }
