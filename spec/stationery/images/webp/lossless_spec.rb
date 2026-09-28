# frozen_string_literal: true

RSpec.describe Stationery::Images::WebP::Lossless do
  def fail_with(message) = raise_error(Stationery::UnsupportedImage, message)
  def load(data) = Stationery::Images::WebP.new(data)

  # The file cut to `size` bytes, its RIFF and chunk sizes saying the same.
  def cut(data, size)
    data.byteslice(0, size).tap do |short|
      short[4, 4] = [size - 8].pack("V")
      short[16, 4] = [size - 20].pack("V")
    end
  end

  it "reads the size and the alpha flag from the header" do
    bitstream = described_class.new(webp("alpha").byteslice(20..))

    expect([bitstream.width, bitstream.height, bitstream.alpha?]).to eq([40, 32, true])
    expect(described_class.new(webp("photo").byteslice(20..)).alpha?).to be(false)
  end

  it "refuses a header that is cut short, not lossless or of another version" do
    expect { load(WebpFactory.riff(WebpFactory.chunk("VP8L", "\x2F\0\0\0"))) }.to fail_with("truncated WebP image")
    expect { load(WebpFactory.build(width: 1, height: 1, signature: 0x2E) { nil }) }
      .to fail_with("invalid WebP image: not a lossless bitstream")
    expect { load(WebpFactory.build(width: 1, height: 1, version: 1) { nil }) }
      .to fail_with("invalid WebP image: unknown lossless version")
  end

  it "refuses more pixels than it will decode, before decoding any" do
    expect { load(WebpFactory.build(width: 16_384, height: 16_384) { nil }) }
      .to fail_with("WebP image too large: 16384x16384 pixels")
  end

  it "refuses a transform that comes twice" do
    data = WebpFactory.build(width: 1, height: 1) { |bits| bits.write(1, 1).write(2, 2).write(1, 1).write(2, 2) }

    expect { load(data) }.to fail_with("invalid WebP image: transform used twice")
  end

  it "adds green back to red and blue" do
    data = WebpFactory.literal(width: 2, height: 1, pixels: [[255, 250, 10, 1], [7, 0, 200, 100]]) do |bits|
      bits.write(1, 1).write(2, 2)
    end

    expect(embedded(load(data))).to eq([[4, 10, 11, 200, 200, 44], [255, 7]])
  end

  it "refuses every file cut short as truncated, wherever the cut is" do
    %w[palette4 palette16 extended].each do |name|
      data = webp(name)
      (0...data.bytesize).each do |size|
        expect { Stationery::Images.parse(data.byteslice(0, size)) }.to raise_error(Stationery::UnsupportedImage)
      end
    end
  end

  it "refuses a bitstream that ends early although the container is whole" do
    %w[palette4 alpha regions].each do |name|
      data = webp(name)
      (25...(data.bytesize - 1)).step(name == "palette4" ? 1 : 97) do |size|
        expect { load(cut(data, size)) }.to fail_with("truncated WebP image")
      end
    end
  end

  it "decodes or refuses a file with damaged bytes, and raises nothing else" do
    random = Random.new(20_260_928)
    %w[palette2 palette4 palette16 extended predictors].each do |name|
      200.times do
        data = webp(name)
        random.rand(1..3).times { data.setbyte(random.rand(data.bytesize), random.rand(256)) }
        begin
          expect(Stationery::Images.parse(data)).to respond_to(:build)
        rescue Stationery::UnsupportedImage => e
          expect(e.message).to match(/WebP|supported/)
        end
      end
    end
  end
end
