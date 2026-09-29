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

  describe "#pixels" do
    %w[ycc420 ycc422_progressive ycc440 ycc411_progressive ycc311 grey_restart rgb extended multiscan successive
       cmyk ycck one_pixel scaled].each do |name|
      it "decodes #{name} to the pixels libjpeg decodes it to" do
        width, height, channels, samples = jpeg_reference(name)
        pixels = jpeg(name).pixels

        expect([pixels.width, pixels.height, pixels.channels, pixels.alpha]).to eq([width, height, channels, nil])
        expect(largest_difference(pixels, samples)).to be <= 1
      end
    end

    it "decodes at a half, a quarter or an eighth of the size, the least that is still as large as asked" do
      image = jpeg("scaled")

      { [32, 24] => 2, [30, 1] => 2, [16, 12] => 4, [9, 5] => 4, [8, 6] => 8, [1, 1] => 8, [33, 1] => nil,
        [1, 25] => nil }.each do |at_least, scale|
        width, height, _, samples = jpeg_reference(scale ? "scaled_#{scale}" : "scaled")
        pixels = image.pixels(at_least:)

        expect([pixels.width, pixels.height]).to eq([width, height])
        expect(largest_difference(pixels, samples)).to be <= 1
      end
    end

    it "decodes each scale once, and builds its rows on every call" do
      image = jpeg("ycc420")
      allow(described_class::Decoder).to receive(:new).and_call_original

      first = image.pixels
      second = image.pixels
      image.pixels(at_least: [4, 4])

      expect(second).to eq(first).and(satisfy { |pixels| !pixels.color.equal?(first.color) })
      expect(described_class::Decoder).to have_received(:new).twice
    end

    it "leaves the EXIF orientation alone, as the PDF does" do
      width, height, = jpeg_reference("exif_rotated")

      expect([jpeg("exif_rotated").pixels.width, height]).to eq([16, 8]).and eq([width, 8])
    end

    { "arithmetic" => "arithmetic-coded JPEG images are not decoded",
      "lossless" => "lossless JPEG images are not decoded",
      "twelve_bit" => "12-bit JPEG images are not decoded" }.each do |name, reason|
      it "refuses a #{name} JPEG, which it still embeds as it is" do
        image = jpeg(name)

        expect(image.unsupported).to eq(reason)
        expect { image.pixels }.to raise_error(Stationery::UnsupportedImage, reason)
        expect(xobject("jpeg/#{name}.jpg").last.data).to eq(File.binread(jpeg_path(name)))
      end
    end

    it "refuses more than MAX_PIXELS" do
      data = File.binread(jpeg_path("ycc420")).b
      frame = data.index("\xFF\xC0".b)
      data[frame + 5, 4] = [8193, 4097].pack("nn")

      expect(described_class.new(data).unsupported).to eq("a JPEG of more than 33554432 pixels is not decoded")
      expect(jpeg("ycc420").unsupported).to be_nil
    end
  end
end
