# frozen_string_literal: true

RSpec.describe Stationery::Fonts::GlyphRun do
  let(:font) { Stationery::Fonts::Font.new(Stationery::Fonts::Registry.load(font_path("OpenSans-Regular.ttf"))) }

  def hex(text) = text.each_char.map { |c| format("%04X", font.ttf.glyph_id(c.ord)) }.join

  it "measures exactly like Font#width_of when there are no adjustments" do
    cases = [["Invoice", 10, 0], ["Hello, world", 12.5, 0], ["Total €", 9, 0.3], ["x", 7.25, -0.1]]
    cases.each do |text, size, spacing|
      expect(font.glyph_run(text).width(size, letter_spacing: spacing))
        .to be_within(1e-9).of(font.width_of(text, size, letter_spacing: spacing))
    end
  end

  it "adds adjustments in thousandths of the size to the width" do
    run = font.glyph_run("abc").with(adjust: [0, 100, 0])

    expect(run.width(10)).to be_within(1e-9).of(font.width_of("abc", 10) + 1)
  end

  it "records the glyphs it uses, like encode" do
    font.glyph_run("Hi")

    expect(font).to be_used
  end

  it "emits a Tj string when every adjustment is zero" do
    expect(font.glyph_run("Hi").to_operator).to eq("<#{hex("Hi")}> Tj")
  end

  it "emits a TJ array grouping unadjusted glyphs and negating adjustments" do
    run = font.glyph_run("abc").with(adjust: [0, -50, 0])

    expect(run.to_operator).to eq("[<#{hex("ab")}> 50 <#{hex("c")}>] TJ")
  end

  it "formats fractional adjustments like other PDF numbers" do
    run = font.glyph_run("ab").with(adjust: [12.345678, 0])

    expect(run.to_operator).to eq("[<#{hex("a")}> -12.3457 <#{hex("b")}>] TJ")
  end

  it "drops a trailing adjustment, which has no visual effect" do
    run = font.glyph_run("ab").with(adjust: [0, 30])

    expect(run.to_operator).to eq("<#{hex("ab")}> Tj")
  end

  it "adds word spacing after space glyphs only" do
    run = font.glyph_run("a b c").with_word_spacing(2, 10)

    expect(run.adjust).to eq([0, 200, 0, 200, 0])
    expect(run.to_operator).to eq("[<#{hex("a ")}> -200 <#{hex("b ")}> -200 <#{hex("c")}>] TJ")
    expect(run.width(10)).to be_within(1e-9).of(font.width_of("a b c", 10) + 4)
  end

  it "measures kerned runs exactly like Font#width_of with kerning" do
    ["AVATAR", "To you", "Wave", "x"].each do |text|
      expect(font.glyph_run(text, kerning: true).width(11, letter_spacing: 0.2))
        .to be_within(1e-9).of(font.width_of(text, 11, letter_spacing: 0.2, kerning: true))
    end
  end
end
