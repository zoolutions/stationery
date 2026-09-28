# frozen_string_literal: true

require "zlib"

RSpec.describe Stationery::Images::Resampled do
  let(:writer) { Stationery::PDF::Writer.new }

  def object(ref) = writer.instance_variable_get(:@objects)[ref.id - 1]
  def pixels(stream) = Zlib::Inflate.inflate(stream.data).bytes
  def png(**) = Stationery::Images::PNG.new(PngFactory.build(**))

  it "averages RGB blocks down to the target width, keeping the aspect ratio" do
    image = png(width: 4, height: 2, color_type: 2,
                rows: [[255, 0, 0, 255, 0, 0, 0, 0, 255, 0, 0, 255], [255, 0, 0, 255, 0, 0, 0, 0, 255, 0, 0, 255]])

    small = image.resample(2)
    stream = object(small.build(writer))

    expect([small.width, small.height]).to eq([2, 1])
    expect(stream.dictionary).to include(Width: 2, Height: 1, ColorSpace: :DeviceRGB, BitsPerComponent: 8,
                                         Filter: :FlateDecode)
    expect(stream.dictionary).not_to have_key(:SMask)
    expect(pixels(stream)).to eq([255, 0, 0, 0, 0, 255])
  end

  it "keeps grey as DeviceGray and averages across a block" do
    small = png(width: 2, height: 2, color_type: 0, rows: [[0, 100], [200, 100]]).resample(1)
    stream = object(small.build(writer))

    expect(stream.dictionary[:ColorSpace]).to eq(:DeviceGray)
    expect(pixels(stream)).to eq([100])
  end

  it "resamples the alpha channel into a soft mask" do
    image = png(width: 2, height: 1, color_type: 6, rows: [[255, 0, 0, 255, 255, 0, 0, 0]])

    stream = object(image.resample(1).build(writer))

    expect(pixels(stream)).to eq([255, 0, 0])
    expect(pixels(object(stream.dictionary[:SMask]))).to eq([127])
  end

  it "expands a palette with transparency into RGB and a soft mask" do
    image = png(width: 2, height: 1, color_type: 3, rows: [[0, 1]], palette: [[255, 0, 0], [0, 0, 255]],
                trns: "\xFF\x00".b)

    stream = object(image.resample(2).build(writer))

    expect(stream.dictionary[:ColorSpace]).to eq(:DeviceRGB)
    expect(pixels(stream)).to eq([255, 0, 0, 0, 0, 255])
    expect(pixels(object(stream.dictionary[:SMask]))).to eq([255, 0])
  end

  it "turns a colour-key transparency into a soft mask and scales 16-bit samples to 8" do
    image = png(width: 2, height: 1, color_type: 2, bit_depth: 16,
                rows: [[65_535, 0, 0, 0, 0, 65_535]], trns: [0, 0, 65_535].pack("n*"))

    stream = object(image.resample(2).build(writer))

    expect(pixels(stream)).to eq([255, 0, 0, 0, 0, 255])
    expect(pixels(object(stream.dictionary[:SMask]))).to eq([255, 0])
  end

  it "reads sub-byte grey depths" do
    image = png(width: 4, height: 1, color_type: 0, bit_depth: 2, rows: [[0b00_01_10_11]], packed: true)

    expect(pixels(object(image.resample(4).build(writer)))).to eq([0, 85, 170, 255])
  end

  it "is memoised per width on the source image" do
    image = png(width: 4, height: 1, color_type: 0, rows: [[0, 0, 0, 0]])

    half = image.resample(2)

    expect(image.resample(2)).to be(half)
    expect(image.resample(1)).not_to be(half)
  end
end
