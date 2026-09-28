# frozen_string_literal: true

RSpec.describe Stationery::Raster::Glyphs do
  let(:font) { Stationery::Fonts::Font.new(Stationery::Fonts::Registry.load(File.join(SpecDocument::FONTS, "OpenSans-Regular.ttf"))) }
  let(:run) { font.glyph_run("HH") }

  def call(**)
    defaults = { run:, x: 10, y: 50, font:, size: 20, color: Stationery::Color.parse("#000000"), letter_spacing: 0,
                 rise: 0, bold: false, oblique: false, opacity: nil, matrix: nil, clip: nil }
    Stationery::Raster::Canvas::Glyphs.new(**defaults, **)
  end

  def xs(path) = path.each_segment.reject { |segment| segment == :close }.map { |_, x, *| x }
  def ys(path) = path.each_segment.reject { |segment| segment == :close }.map { |_, _, y, *| y }

  it "puts each glyph at the pen, moved on by its advance and the letter spacing" do
    advance = font.ttf.advance(run.gids.first) * 20 / font.ttf.units_per_em.to_f
    plain = described_class.path(call, [1, 0, 0, 1, 0, 0], antialias: false)
    spaced = described_class.path(call(letter_spacing: 5), [1, 0, 0, 1, 0, 0], antialias: false)

    expect(xs(plain).min).to be_between(10, 14)
    expect(xs(plain).max).to be_between(10 + advance, 10 + (2 * advance))
    expect(xs(spaced).max - xs(plain).max).to be_within(1).of(5)
  end

  it "stands the glyphs on the baseline, raised by the rise" do
    path = described_class.path(call(rise: 4), [1, 0, 0, 1, 0, 0], antialias: false)

    expect(ys(path).max).to be_within(0.01).of(46)
  end

  it "shears an oblique run about the baseline" do
    upright = described_class.path(call, [1, 0, 0, 1, 0, 0], antialias: true)
    oblique = described_class.path(call(oblique: true), [1, 0, 0, 1, 0, 0], antialias: true)

    expect(xs(oblique).max).to be > xs(upright).max
    expect(xs(oblique).min).to be_within(0.3).of(xs(upright).min)
  end
end
