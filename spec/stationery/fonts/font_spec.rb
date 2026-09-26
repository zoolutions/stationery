# frozen_string_literal: true

RSpec.describe Stationery::Fonts::Font do
  subject(:font) { described_class.new(Stationery::Fonts::Registry.load(font_path("OpenSans-Regular.ttf"))) }

  let(:writer) { Stationery::PDF::Writer.new }

  def object(ref) = writer.instance_variable_get(:@objects)[ref.id - 1]

  it "measures text in points, with letter spacing per character" do
    plain = font.width_of("Invoice", 10)

    expect(plain).to be_within(3).of(33)
    expect(font.width_of("Invoice", 20)).to be_within(0.001).of(plain * 2)
    expect(font.width_of("Invoice", 10, letter_spacing: 1)).to be_within(0.001).of(plain + 7)
  end

  it "exposes vertical metrics scaled to a size" do
    expect(font.ascender(10)).to be_between(9, 12)
    expect(font.descender(10)).to be_between(2, 4)
    expect(font.line_height(10)).to be > 10
  end

  it "encodes text as two-byte glyph ids and remembers which characters were used" do
    encoded = font.encode("Hi")

    expect(encoded.bytesize).to eq(4)
    expect(encoded.unpack("n*")).to eq("Hi".chars.map { |c| font.ttf.glyph_id(c.ord) })
  end

  it "builds a Type0 font over a CIDFontType2 with Identity-H, a subset and ToUnicode" do
    font.encode("Hi €")
    type0 = object(font.build(writer))
    cid = object(type0[:DescendantFonts].first)
    descriptor = object(cid[:FontDescriptor])

    expect(type0).to include(Subtype: :Type0, Encoding: :"Identity-H")
    expect(type0[:BaseFont].to_s).to match(/\A[A-Z]{6}\+OpenSans-Regular\z/)
    expect(cid).to include(Subtype: :CIDFontType2)
    expect(descriptor[:FontFile2]).to be_a(Stationery::PDF::Reference)
    expect(object(type0[:ToUnicode])).to be_a(Stationery::PDF::Stream)
  end

  it "maps glyphs back to Unicode in chunks of at most 100" do
    alphabet = [*"A".."Z", *"a".."z", *"0".."9"].join
    font.encode("#{alphabet}ÅÄÖåäöÜüéèàç.,;:!?-()[]{}'\"/\\@#$%&*+=<>|~^_`")
    cmap = font.send(:to_unicode_cmap)

    expect(cmap.scan(/(\d+) beginbfchar/).flatten.map(&:to_i)).to all(be <= 100)
    expect(cmap).to include("<00E5>") # å
  end
end
