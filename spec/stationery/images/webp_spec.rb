# frozen_string_literal: true

require "stringio"
require "zlib"

RSpec.describe Stationery::Images::WebP do
  let(:writer) { Stationery::PDF::Writer.new }

  def object(ref) = writer.instance_variable_get(:@objects)[ref.id - 1]

  %w[photo palette2 palette4 palette16 palette60 extended].each do |name|
    it "decodes #{name}.webp to the pixels libwebp decodes it to" do
      width, height, color, = reference(name)
      image = described_class.new(webp(name))

      expect([image.width, image.height]).to eq([width, height])
      expect(embedded(image)).to eq([color, nil])
    end
  end

  %w[alpha predictors indexed4 indexed9 indexed20].each do |name|
    it "decodes #{name}.webp with its alpha channel" do
      width, height, color, alpha = reference(name)
      image = described_class.new(webp(name))

      expect([image.width, image.height]).to eq([width, height])
      expect(embedded(image)).to eq([color, alpha])
    end
  end

  it "embeds RGB as a Flate stream, without a soft mask when every pixel is opaque" do
    stream = object(described_class.new(webp("photo")).build(writer))

    expect(stream.dictionary).to include(Type: :XObject, Subtype: :Image, Width: 40, Height: 32,
                                         ColorSpace: :DeviceRGB, BitsPerComponent: 8, Filter: :FlateDecode)
    expect(stream.dictionary).not_to have_key(:SMask)
  end

  it "embeds the alpha channel as a soft mask" do
    stream = object(described_class.new(webp("alpha")).build(writer))
    mask = object(stream.dictionary[:SMask])

    expect(mask.dictionary).to include(Type: :XObject, Subtype: :Image, Width: 40, Height: 32,
                                       ColorSpace: :DeviceGray, BitsPerComponent: 8, Filter: :FlateDecode)
  end

  it "leaves the soft mask out when the alpha channel is there but opaque, or marked unused" do
    pixels = [[255, 10, 20, 30], [255, 40, 50, 60]]
    ignored = [[0, 10, 20, 30], [128, 40, 50, 60]]

    expect(embedded(described_class.new(WebpFactory.literal(width: 2, height: 1, pixels:))))
      .to eq([[10, 20, 30, 40, 50, 60], nil])
    expect(embedded(described_class.new(WebpFactory.literal(width: 2, height: 1, pixels: ignored, alpha: false))))
      .to eq([[10, 20, 30, 40, 50, 60], nil])
  end

  it "resamples through Resampled, alpha included" do
    pixels = [[255, 200, 0, 0], [0, 100, 0, 0], [255, 0, 0, 50], [255, 0, 0, 150]]
    image = described_class.new(WebpFactory.literal(width: 4, height: 1, pixels:))

    small = image.resample(2)

    expect(small).to be_a(Stationery::Images::Resampled).and equal(image.resample(2))
    expect([small.width, small.height]).to eq([2, 1])
    expect(embedded(small)).to eq([[150, 0, 0, 0, 0, 100], [127, 255]])
  end

  it "resamples an opaque image without a soft mask" do
    expect(embedded(described_class.new(webp("photo")).resample(10)).last).to be_nil
  end

  it "inspects as its size" do
    expect(described_class.new(webp("photo")).inspect).to eq("#<Stationery::Images::WebP 40x32>")
  end

  describe "in a document" do
    def render(node)
      resources = Stationery::Resources.new
      paginator = Stationery::Layout::Paginator.new(resources:, page: { size: [300, 200], margin: 20 })
      pages = paginator.paginate(Stationery::Layout::Flow.new([node]))
      [Stationery::PDF::Assembler.new(pages:, resources:).render, paginator.warnings.to_a]
    end

    it "is loaded by its signature, once for the same bytes" do
      image = Stationery::Images.load(webp_path("photo"))

      expect(image).to be_a(described_class).and equal(Stationery::Images.load(StringIO.new(webp("photo"))))
    end

    it "draws with a size, cover fit and rounded corners" do
      node = Stationery::Layout::Image.new(webp_path("alpha"), width: 100, height: 50, fit: :cover, radius: 6)
      pdf, warnings = render(node)

      expect(node.size(260)).to eq([100, 50])
      expect(image_count(pdf)).to eq(2) # the image and its soft mask
      expect(pdf).to include("/SMask")
      expect(warnings).to be_empty
    end

    it "warns when drawn above the ppi limit and downscales when asked" do
      pdf, warnings = render(Stationery::Layout::Image.new(webp_path("photo"), width: 4))
      expect(warnings.map(&:class)).to eq([Stationery::Warnings::OversizedImage])
      expect(pdf).to include("/Width 40")

      pdf, warnings = render(Stationery::Layout::Image.new(webp_path("photo"), width: 4, downscale: true))
      expect(warnings).to be_empty
      expect(pdf).to include("/Width 17").and include("/Height 14")
    end
  end
end
