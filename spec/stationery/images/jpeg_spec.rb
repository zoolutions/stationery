# frozen_string_literal: true

RSpec.describe Stationery::Images::JPEG do
  let(:writer) { Stationery::PDF::Writer.new }

  def xobject(name)
    image = Stationery::Images.load(image_path(name))
    ref = image.build(writer)
    [image, writer.instance_variable_get(:@objects)[ref.id - 1]]
  end

  it "reads dimensions and passes the bytes through as DCTDecode" do
    image, stream = xobject("rgb.jpg")

    expect([image.width, image.height]).to eq([4, 3])
    expect(stream.dictionary).to include(Subtype: :Image, Filter: :DCTDecode, ColorSpace: :DeviceRGB,
                                         BitsPerComponent: 8)
    expect(stream.data).to eq(File.binread(image_path("rgb.jpg")))
  end

  it "maps one component to DeviceGray" do
    expect(xobject("gray.jpg").last.dictionary[:ColorSpace]).to eq(:DeviceGray)
  end

  it "accepts progressive JPEGs" do
    expect(xobject("progressive.jpg").first.width).to eq(4)
  end

  it "inverts Adobe CMYK JPEGs with a Decode array" do
    stream = xobject("cmyk.jpg").last

    expect(stream.dictionary).to include(ColorSpace: :DeviceCMYK, Decode: [1, 0, 1, 0, 1, 0, 1, 0])
  end

  it "rejects a truncated JPEG" do
    expect { described_class.new("\xFF\xD8\xFF".b) }.to raise_error(Stationery::UnsupportedImage, /invalid JPEG/)
  end
end
