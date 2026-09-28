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
