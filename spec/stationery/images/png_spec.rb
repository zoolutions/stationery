# frozen_string_literal: true

require "zlib"

RSpec.describe Stationery::Images::PNG do
  let(:writer) { Stationery::PDF::Writer.new }

  def objects = writer.instance_variable_get(:@objects)
  def object(ref) = objects[ref.id - 1]

  def embed(png)
    image = described_class.new(png)
    [image, object(image.build(writer))]
  end

  def pixels(stream) = Zlib::Inflate.inflate(stream.data).bytes

  it "embeds opaque RGB by passing the compressed data through with a PNG predictor" do
    png = PngFactory.build(width: 2, height: 1, color_type: 2, rows: [[255, 0, 0, 0, 0, 255]])
    image, stream = embed(png)

    expect([image.width, image.height]).to eq([2, 1])
    expect(stream.dictionary).to include(ColorSpace: :DeviceRGB, BitsPerComponent: 8,
                                         DecodeParms: { Predictor: 15, Colors: 3, BitsPerComponent: 8, Columns: 2 })
    expect(stream.dictionary).not_to have_key(:SMask)
  end

  it "embeds greyscale as DeviceGray" do
    _image, stream = embed(PngFactory.build(width: 2, height: 1, color_type: 0, rows: [[0, 255]]))

    expect(stream.dictionary[:ColorSpace]).to eq(:DeviceGray)
  end

  it "embeds a palette as an Indexed colour space" do
    png = PngFactory.build(width: 2, height: 1, color_type: 3, rows: [[0, 1]], palette: [[255, 0, 0], [0, 0, 255]])
    _image, stream = embed(png)

    base, lookup_base, hival, lookup = stream.dictionary[:ColorSpace]
    expect([base, lookup_base, hival]).to eq([:Indexed, :DeviceRGB, 1])
    expect(lookup.bytes).to eq("\xFF\x00\x00\x00\x00\xFF".b)
  end

  it "splits RGBA into colour and a soft mask" do
    png = PngFactory.build(width: 2, height: 1, color_type: 6, rows: [[255, 0, 0, 128, 0, 255, 0, 255]])
    _image, stream = embed(png)
    mask = object(stream.dictionary[:SMask])

    expect(pixels(stream)).to eq([255, 0, 0, 0, 255, 0])
    expect(pixels(mask)).to eq([128, 255])
    expect(mask.dictionary).to include(ColorSpace: :DeviceGray, BitsPerComponent: 8)
  end

  it "splits grey+alpha into colour and a soft mask" do
    _image, stream = embed(PngFactory.build(width: 2, height: 1, color_type: 4, rows: [[10, 0, 20, 255]]))

    expect(pixels(stream)).to eq([10, 20])
    expect(pixels(object(stream.dictionary[:SMask]))).to eq([0, 255])
  end

  it "reduces 16-bit RGBA to 8 bits per sample" do
    png = PngFactory.build(width: 1, height: 1, color_type: 6, bit_depth: 16,
                           rows: [[0xFF00, 0x8000, 0x0000, 0x4000]])
    _image, stream = embed(png)

    expect(pixels(stream)).to eq([0xFF, 0x80, 0x00])
    expect(pixels(object(stream.dictionary[:SMask]))).to eq([0x40])
  end

  it "turns palette transparency into a soft mask, opaque for entries without an alpha" do
    png = PngFactory.build(width: 3, height: 1, color_type: 3, rows: [[0, 1, 2]],
                           palette: [[255, 0, 0], [0, 255, 0], [0, 0, 255]], trns: [0, 64].pack("C*"))
    _image, stream = embed(png)

    expect(pixels(object(stream.dictionary[:SMask]))).to eq([0, 64, 255])
  end

  it "unpacks sub-byte palette indexes when building the soft mask" do
    png = PngFactory.build(width: 4, height: 1, color_type: 3, bit_depth: 2, rows: [[0b00_01_10_11]], packed: true,
                           palette: [[0, 0, 0], [1, 1, 1], [2, 2, 2], [3, 3, 3]], trns: [0, 50, 100].pack("C*"))
    _image, stream = embed(png)

    expect(pixels(object(stream.dictionary[:SMask]))).to eq([0, 50, 100, 255])
  end

  it "turns grey or RGB tRNS into a colour-key mask" do
    png = PngFactory.build(width: 1, height: 1, color_type: 2, rows: [[1, 2, 3]], trns: [1, 2, 3].pack("n*"))
    _image, stream = embed(png)

    expect(stream.dictionary[:Mask]).to eq([1, 1, 2, 2, 3, 3])
  end

  [0, 1, 2, 3, 4].each do |filter|
    it "reverses scanline filter #{filter}" do
      png = PngFactory.build(width: 2, height: 1, color_type: 6, filter:, rows: [[10, 20, 30, 40, 50, 60, 70, 80]])
      _image, stream = embed(png)

      expect(pixels(stream)).to eq([10, 20, 30, 50, 60, 70])
      expect(pixels(object(stream.dictionary[:SMask]))).to eq([40, 80])
    end
  end

  it "rejects interlaced PNGs" do
    expect { described_class.new(File.binread(image_path("interlaced.png"))) }
      .to raise_error(Stationery::UnsupportedImage, /interlaced/)
  end
end
