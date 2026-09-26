# frozen_string_literal: true

RSpec.describe Stationery::Fonts::Registry do
  it "parses a font once and returns the cached parse for the same file" do
    first = described_class.load(font_path("OpenSans-Regular.ttf"))

    expect(described_class.load(font_path("OpenSans-Regular.ttf"))).to equal(first)
  end

  it "raises a clear error for a missing file" do
    expect { described_class.load("/nope/Missing.ttf") }.to raise_error(Stationery::UnsupportedFont, /not found/)
  end

  it "is safe to call from many threads at once" do
    results = Array.new(8) { Thread.new { described_class.load(font_path("OpenSans-Bold.ttf")) } }.map(&:value)

    expect(results.uniq(&:object_id).size).to eq(1)
  end
end
