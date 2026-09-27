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
end
