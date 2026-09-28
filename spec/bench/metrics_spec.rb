# frozen_string_literal: true

require_relative "../../benchmark/metrics"

# The metrics gate (`bundle exec rake metrics`) holds a document for each
# thing a render can do that allocates on a path of its own, so these say
# that each document takes the path it is named after.
RSpec.describe Bench::Metrics do
  def document(name) = described_class::DOCUMENTS.fetch(name).call
  def render(name) = described_class.render(name)
  def streams_of(page) = Array(page.attributes[:Contents]).size

  it "renders a document for what 0.11 added beside the seven it rendered" do
    expect(described_class::DOCUMENTS.keys)
      .to eq(%w[invoice table text text_hyphenated flyer form text_streamed
                article newsletter webp html pdf_ua text_incremental text_shaped])
  end

  it "has a baseline for every document it renders" do
    recorded = described_class.baselines.transform_values { |baseline| baseline.fetch("documents").keys }

    expect(recorded.keys).to include("3.4")
    expect(recorded.values).to all(eq(described_class::DOCUMENTS.keys))
  end

  it "reads what it renders from the repository alone" do
    sources = [Bench::WEBP, Bench::FONT, Bench::FONT_BOLD, Bench::COVER]

    expect(sources).to all(start_with(File.expand_path("../..", __dir__)).and(satisfy { |path| File.file?(path) }))
  end

  describe "webp" do
    it "draws a lossless WebP" do
      expect(File.binread(Bench::WEBP, 16)).to match(/\ARIFF....WEBPVP8L/mn)
      expect(image_count(render("webp"))).to eq(1)
    end

    it "decodes it in every render, the measured one too" do
      decoded = 0
      allow(Stationery::Images::WebP).to receive(:new).and_wrap_original do |original, *arguments, **options|
        decoded += 1
        original.call(*arguments, **options)
      end

      3.times { render("webp") }

      expect(decoded).to eq(3)
    end
  end

  describe "html" do
    it "reads every rule of its stylesheet" do
      html = document("html")
      pdf = html.to_pdf

      expect(html.warnings).to be_empty
      expect(page_count(pdf)).to be > 1
      expect(text_of(pdf)).to include("Harbour dues")
    end
  end

  describe "pdf_ua" do
    it "claims PDF/UA-1 and passes the audit" do
      pdf = render("pdf_ua")

      expect(pdf).to include("<pdfuaid:part>1</pdfuaid:part>")
      expect(document("pdf_ua")).to have_tagged_content
    end
  end

  describe "text_incremental" do
    it "writes the footer as a content stream of its own" do
      pages = reader_for(render("text_incremental")).pages

      expect(pages.map { |page| streams_of(page) }).to all(eq(2))
      expect(pages.first.text).to include("Page 1 of #{pages.size}")
    end

    it "is the text document with a footer" do
      expect(reader_for(Bench::StationeryIncremental.new.to_pdf(incremental: false)).pages
        .map { |page| streams_of(page) }).to all(eq(1))
    end
  end

  describe "text_shaped" do
    it "hands every stretch of text to the shaper" do
      allow(Bench::Shaper).to receive(:call).and_call_original

      pdf = render("text_shaped")

      expect(Bench::Shaper).to have_received(:call).at_least(:once)
      expect(text_of(pdf)).to include("Section 50", "We believe a good month")
    end

    it "answers the font's own glyphs with their advances" do
      face = Stationery::Shaper::Face.new(path: Bench::FONT, index: 0, data: nil, units_per_em: 2048,
                                          postscript_name: "OpenSans-Regular", glyph_count: 0)
      ttf = Stationery::Fonts::Registry.load(Bench::FONT)

      glyphs = Bench::Shaper.call("Hi", face, size: 10, features: {}, language: nil)

      expect(glyphs.map(&:to_h)).to eq(
        "Hi".each_char.with_index.map do |char, index|
          { gid: ttf.glyph_id(char.ord), advance: ttf.advance(ttf.glyph_id(char.ord)), cluster: index,
            x_offset: 0, y_offset: 0 }
        end
      )
    end
  end
end
