# frozen_string_literal: true

require "stringio"

RSpec.describe Stationery::Images do
  it "detects JPEG, PNG and WebP by their magic bytes, from a path, a Pathname or an IO" do
    expect(described_class.load(image_path("webp/photo.webp"))).to be_a(Stationery::Images::WebP)
    expect(described_class.load(image_path("rgb.jpg"))).to be_a(Stationery::Images::JPEG)
    expect(described_class.load(Pathname(image_path("gray.jpg")))).to be_a(Stationery::Images::JPEG)
    png = PngFactory.build(width: 1, height: 1, color_type: 0, rows: [[0]])
    expect(described_class.load(StringIO.new(png))).to be_a(Stationery::Images::PNG)
  end

  it "reads an IO from the start even if it was already read" do
    io = StringIO.new(File.binread(image_path("rgb.jpg")))
    io.read

    expect(described_class.load(io).width).to eq(4)
  end

  it "names formats it cannot embed" do
    expect { described_class.load(image_path("webp.webp")) }
      .to raise_error(Stationery::UnsupportedImage, /\Alossy WebP images are not supported/)
    expect { described_class.load(image_path("gif.gif")) }.to raise_error(Stationery::UnsupportedImage, /GIF/)
    ["nope", "RIFF\x04\0\0\0WAVE"].each do |data|
      expect { described_class.load(StringIO.new(data)) }
        .to raise_error(Stationery::UnsupportedImage, "only JPEG, PNG and lossless WebP images are supported")
    end
  end

  it "returns the same decoded image for the same bytes" do
    expect(described_class.load(image_path("rgb.jpg"))).to equal(described_class.load(image_path("rgb.jpg")))
  end
end
