# frozen_string_literal: true

RSpec.describe Stationery::Images::WebP::ImageStream do
  def fail_with(message) = raise_error(Stationery::UnsupportedImage, message)
  def load(data) = Stationery::Images::WebP.new(data)

  # An image whose green code holds the literals 10 and 20 and one length
  # code, with red, blue and alpha fixed; the block writes the pixels.
  def coded(width:, height:, length:, distance:, cache: nil)
    WebpFactory.build(width:, height:) do |bits|
      bits.write(0, 1) # no transform
      cache ? bits.write(1, 1).write(cache, 4) : bits.write(0, 1)
      bits.write(0, 1) # no entropy image
      lengths = Array.new(280 + (cache ? 1 << cache : 0), 0)
      lengths[10] = 1
      lengths[20] = 2
      lengths[256 + length] = 2
      green = bits.code(lengths)
      bits.single(1).single(2).single(255).single(distance)
      yield bits, green
    end
  end

  it "copies pixels from a distance back, overlapping itself" do
    data = coded(width: 4, height: 1, length: 2, distance: 1) do |bits, green|
      bits.word(*green[20]).word(*green[258]) # one pixel, then three more from one back
    end

    expect(embedded(load(data))).to eq([[1, 20, 2] * 4, nil])
  end

  it "maps the short distance codes to neighbours: code 1 is the pixel above" do
    data = coded(width: 2, height: 2, length: 1, distance: 0) do |bits, green|
      bits.word(*green[10]).word(*green[20]).word(*green[257])
    end

    expect(embedded(load(data))).to eq([[1, 10, 2, 1, 20, 2] * 2, nil])
  end

  it "reads distances beyond the neighbours with their extra bits" do
    # Symbol 13 and 5 extra bits of 25: distance code 122, two pixels back.
    data = coded(width: 4, height: 1, length: 1, distance: 13) do |bits, green|
      bits.word(*green[10]).word(*green[20]).word(*green[257]).write(25, 5)
    end

    expect(embedded(load(data))).to eq([[1, 10, 2, 1, 20, 2] * 2, nil])
  end

  it "takes a neighbour that is no earlier pixel for the one before" do
    # Code 4 is one up and one to the right: in a column, the current pixel.
    data = coded(width: 1, height: 3, length: 1, distance: 3) do |bits, green|
      bits.word(*green[20]).word(*green[257])
    end

    expect(embedded(load(data))).to eq([[1, 20, 2] * 3, nil])
  end

  it "refuses a reference to before the first pixel" do
    data = coded(width: 4, height: 1, length: 1, distance: 1) do |bits, green|
      bits.word(*green[257]).word(*green[10])
    end

    expect { load(data) }.to fail_with("invalid WebP image: backward reference out of range")
  end

  it "refuses a copy that runs past the last pixel" do
    data = coded(width: 2, height: 1, length: 2, distance: 1) do |bits, green|
      bits.word(*green[10]).word(*green[258])
    end

    expect { load(data) }.to fail_with("invalid WebP image: backward reference past the end")
  end

  it "refuses a colour cache of no or too many bits" do
    [0, 12].each do |cache|
      data = coded(width: 1, height: 1, length: 1, distance: 0, cache:) { |bits, green| bits.word(*green[10]) }

      expect { load(data) }.to fail_with("invalid WebP image: colour cache size")
    end
  end

  it "decodes an image of block-wise prefix codes and a colour cache like libwebp" do
    width, height, color, = reference("regions")
    image = load(webp("regions"))

    expect([image.width, image.height]).to eq([width, height])
    expect(embedded(image)).to eq([color, nil])
  end

  it "reads the codes of groups no block uses without keeping them" do
    data = WebpFactory.build(width: 2, height: 1, alpha: true) do |bits|
      bits.write(0, 1).write(0, 1) # no transform, no colour cache
      bits.write(1, 1).write(0, 3) # an entropy image of 4x4 blocks: one block, in group 1
      bits.write(0, 1).single(1).single(0).single(0).single(0).single(0)
      [[9, 9, 9, 9], [30, 40, 50, 60]].each do |green, red, blue, alpha|
        bits.single(green).single(red).single(blue).single(alpha).single(0)
      end
    end

    expect(embedded(load(data))).to eq([[40, 30, 50] * 2, [60, 60]])
  end
end
