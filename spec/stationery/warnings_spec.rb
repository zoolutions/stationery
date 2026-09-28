# frozen_string_literal: true

RSpec.describe Stationery::Warnings do
  let(:warnings) { described_class.new }

  it "starts empty" do
    expect(warnings).to be_empty
    expect(warnings.size).to eq(0)
    expect(warnings.to_a).to eq([])
    expect(warnings.each).to be_an(Enumerator)
  end

  it "keeps one of each equal warning" do
    warnings << described_class::SkippedImage.new(source: "a.webp", reason: "WebP")
    warnings << described_class::SkippedImage.new(source: "a.webp", reason: "WebP")
    warnings << described_class::SkippedImage.new(source: "b.gif", reason: "GIF")

    expect(warnings.size).to eq(2)
    expect(warnings.map(&:source)).to eq(%w[a.webp b.gif])
  end

  it "returns itself from <<" do
    expect(warnings << described_class::UnresolvedLink.new(name: "x", page: 1)).to be(warnings)
  end

  it "counts missing glyphs per character and family, reported after the other warnings" do
    3.times { warnings.missing_glyph("☃", "Inter") }
    warnings.missing_glyph("☃", "Open Sans")
    warnings << described_class::DuplicateAnchor.new(name: "top", page: 2)

    glyphs = warnings.grep(described_class::MissingGlyph)
    expect(warnings.first).to be_a(described_class::DuplicateAnchor)
    expect(glyphs.map(&:count)).to eq([3, 1])
    expect(glyphs.first.message).to eq('missing glyph "☃" (U+2603) in Inter, drawn 3 times as .notdef')
    expect(glyphs.last.message).to end_with("drawn once as .notdef")
    expect(warnings).to be_any
  end

  it "aliases the layout overflow" do
    expect(described_class::Overflow).to be(Stationery::Layout::Overflow)
  end

  it "explains every kind" do
    expect(described_class::UnknownFamily.new(requested: "X", used: "Y").message)
      .to eq('font family "X" is not registered, using "Y"')
    expect(described_class::UnsupportedSvg.new(elements: %w[mask image], source: "logo.svg").message)
      .to eq('SVG "logo.svg" uses unsupported elements: mask, image')
    expect(described_class::SkippedImage.new(source: "a.webp", reason: "WebP is not supported").message)
      .to eq('image "a.webp" skipped: WebP is not supported')
    expect(described_class::UnresolvedLink.new(name: "terms", page: 3).message)
      .to eq('link to "terms" on page 3 has no matching anchor')
    expect(described_class::DuplicateAnchor.new(name: "top", page: 2).message)
      .to eq('anchor "top" on page 2 is already defined')
    expect(described_class::UnsupportedCss.new(properties: %w[float display], selectors: ["a > b"]).message)
      .to eq("html styles not read: properties float, display; selectors a > b")
    expect(described_class::UnsupportedCss.new(properties: [], selectors: ["a b"]).message)
      .to eq("html styles not read: selectors a b")
    expect(described_class::DroppedLink.new(href: "javascript:alert(1)").message)
      .to eq('link "javascript:alert(1)" dropped: scheme not allowed')
  end

  describe "WarningsError" do
    it "lists every warning in its message and exposes them" do
      warnings << Stationery::Layout::Overflow.new(page: 1, height: 300, available: 160)
      warnings.missing_glyph("☃", "Inter")
      error = Stationery::WarningsError.new(warnings)

      expect(error).to be_a(Stationery::Error)
      expect(error.warnings).to be(warnings)
      expect(error.message).to eq(<<~MESSAGE.chomp)
        2 warnings:
          content 300.0pt tall placed on page 1 with 160.0pt available
          missing glyph "☃" (U+2603) in Inter, drawn once as .notdef
      MESSAGE
    end
  end
end
