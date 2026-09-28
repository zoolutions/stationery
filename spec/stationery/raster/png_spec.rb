# frozen_string_literal: true

RSpec.describe Stationery::Raster::PNG do
  def chunks(png)
    pos = 8
    found = []
    while pos < png.bytesize
      length, type = png.byteslice(pos, 8).unpack("Na4")
      data = png.byteslice(pos + 8, length)
      expect(png.byteslice(pos + 8 + length, 4).unpack1("N")).to eq(Zlib.crc32(type + data))
      found << [type, data]
      pos += 12 + length
    end
    found
  end

  it "encodes 8-bit RGB rows as a PNG any decoder reads back" do
    rgb = [255, 0, 0, 0, 255, 0, 0, 0, 255, 10, 20, 30].pack("C*")
    png = described_class.encode(rgb, width: 2, height: 2, channels: 3)
    pixels = Stationery::Images::PNG.new(png).pixels

    expect(png.byteslice(0, 8)).to eq("\x89PNG\r\n\x1A\n".b)
    expect(chunks(png).map(&:first)).to eq(%w[IHDR IDAT IEND])
    expect(chunks(png).first.last.unpack("NNCCCCC")).to eq([2, 2, 8, 2, 0, 0, 0])
    expect(pixels.color).to eq([[255, 0, 0, 0, 255, 0], [0, 0, 255, 10, 20, 30]])
  end

  it "encodes 8-bit grey" do
    png = described_class.encode([0, 128, 255].pack("C*"), width: 3, height: 1, channels: 1)

    expect(chunks(png).first.last.unpack("NNCCCCC")).to eq([3, 1, 8, 0, 0, 0, 0])
    expect(Stationery::Images::PNG.new(png).pixels.color).to eq([[0, 128, 255]])
  end

  it "encodes rows packed one bit to a pixel, 1 for white, as grey of bit depth 1" do
    bits = [0b1010_0000, 0b0111_1111].pack("C*")
    png = described_class.encode(bits, width: 3, height: 2, channels: 1, depth: 1)

    expect(chunks(png).first.last.unpack("NNCCCCC")).to eq([3, 2, 1, 0, 0, 0, 0])
    expect(Stationery::Images::PNG.new(png).pixels.color).to eq([[255, 0, 255], [0, 255, 255]])
  end
end
