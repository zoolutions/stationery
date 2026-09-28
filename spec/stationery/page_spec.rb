# frozen_string_literal: true

RSpec.describe Stationery::Page do
  it "knows the standard paper sizes in points" do
    expect(described_class.new(size: :a4).size).to eq([595.28, 841.89])
    expect(described_class.new(size: :letter).size).to eq([612, 792])
    expect(described_class.new(size: "LEGAL").size).to eq([612, 1008])
    expect(described_class.new(size: [300, 400]).size).to eq([300, 400])
  end

  it "swaps width and height for landscape" do
    expect(described_class.new(size: :letter, layout: :landscape).size).to eq([792, 612])
  end

  it "computes the content box inside the margins, top-left origin" do
    page = described_class.new(size: :letter, margin: [36, 40, 50, 30])

    expect(page.content_box).to eq(Stationery::Rect.new(30, 36, 612 - 70, 792 - 86))
  end

  it "takes header and footer space out of the content box but not the margin box" do
    page = described_class.new(size: [300, 200], margin: 20, reserve: [30, 15])

    expect(page.margin_box).to eq(Stationery::Rect.new(20, 20, 260, 160))
    expect(page.content_box).to eq(Stationery::Rect.new(20, 50, 260, 115))
    expect(page.reserve).to eq([30, 15])
  end

  it "rejects unknown sizes" do
    expect { described_class.new(size: :b9) }.to raise_error(ArgumentError, /page size/)
    expect { described_class.new(size: %w[102mm 74]) }.to raise_error(ArgumentError, /page size/)
  end

  it "knows the small sheets, envelopes and label stock from their millimetres and inches" do
    millimetres = { a6: [105, 148], a7: [74, 105], b5: [176, 250], dl: [110, 220], c5: [162, 229], c6: [114, 162],
                    label_100x150: [100, 150], label_100x50: [100, 50] }

    millimetres.each do |name, size|
      expect(described_class.new(size: name).size).to eq(size.map { (it * 72 / 25.4).round(2) })
    end
    expect(described_class.new(size: :label_4x6).size).to eq([288, 432])
    expect(described_class.new(size: :label_4x3).size).to eq([288, 216])
    expect(described_class.new(size: :label_4x2).size).to eq([288, 144])
    expect(described_class.new(size: :dl, layout: :landscape).size).to eq([623.62, 311.81])
  end

  it "keeps the sizes it had to the point" do
    expect(described_class::SIZES).to include(
      a3: [841.89, 1190.55], a4: [595.28, 841.89], a5: [419.53, 595.28],
      letter: [612, 792], legal: [612, 1008], tabloid: [792, 1224]
    )
  end

  it "takes sizes and margins with their units" do
    page = described_class.new(size: %w[4in 6in], margin: ["0.5in", "18pt"], layout: "landscape")

    expect(page.size).to eq([432, 288])
    expect(page.margin).to eq([36, 18, 36, 18])
    expect(described_class.new(size: "4in x 6in", margin: "1in").margin_box)
      .to eq(Stationery::Rect.new(72, 72, 144, 288))
  end

  it "takes a size in points as it did, whatever the numbers" do
    expect(described_class.new(size: [0, 0]).size).to eq([0, 0])
    expect(described_class.new(size: [300.5, 400], margin: { x: 10 }).margin).to eq([0, 10, 0, 10])
  end

  describe "#seal" do
    let(:page) { described_class.new(size: [300, 200]) }

    it "deflates what was painted into the body and starts the content afresh" do
      page.content << "q\nQ\n"
      page.seal

      expect(page).to be_sealed
      expect(page.body).to be_a(Stationery::PDF::Stream)
      expect(Zlib::Inflate.inflate(page.body.data)).to eq("q\nQ\n")
      expect(page.content).to eq("").and have_attributes(encoding: Encoding::BINARY)
      expect(page.background).to eq("")
    end

    it "keeps what the block makes of the stream as the body" do
      reference = Stationery::PDF::Reference.new(7)

      expect(page.seal { |stream| stream.is_a?(Stationery::PDF::Stream) && reference }).to be(page)
      expect(page.body).to be(reference)
    end

    it "is not sealed until asked" do
      expect(page).not_to be_sealed
      expect(page.body).to be_nil
      expect(page.background).to be_nil
    end
  end

  describe "#lower" do
    let(:page) { described_class.new(size: [300, 200]) }

    it "moves what was painted after the mark under the content of an open page" do
      page.content << "body\n" << "under\n"
      page.lower(5)

      expect(page.content).to eq("under\nbody\n")
    end

    it "moves it under the body of a sealed page, the last lowered lowest" do
      page.content << "body\n"
      page.seal
      page.content << "over\n" << "under\n"
      page.lower(5)
      page.content << "lowest\n"
      page.lower(5)

      expect(page.content).to eq("over\n")
      expect(page.background).to eq("lowest\nunder\n")
    end
  end
end
