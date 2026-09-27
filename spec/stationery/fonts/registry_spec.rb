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

  it "loads the face a #N suffix selects from a collection, face 0 without one" do
    path = font_path("OpenSans-Collection.ttc")

    expect(described_class.load("#{path}#1").postscript_name).to eq("OpenSans-Bold")
    expect(described_class.load("#{path}#0").postscript_name).to eq("OpenSans-Regular")
    expect(described_class.load(path)).to equal(described_class.load("#{path}#0"))
  end

  it "names the file, not the suffix, when a collection is missing" do
    expect { described_class.load("/nope/Missing.ttc#1") }
      .to raise_error(Stationery::UnsupportedFont, %r{not found: /nope/Missing.ttc\z})
  end
end
