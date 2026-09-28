# frozen_string_literal: true

# Lines beside floats: every line asks for the width it has at its own top.
RSpec.describe Stationery::Text::Wrapper do
  let(:book) { open_sans_book }
  let(:words) { Array.new(40) { |i| "word#{i}" }.join(" ") }

  def band(top, bottom, left, right) = Stationery::Text::Exclusions::Band.new(top:, bottom:, left:, right:)
  def exclusions(*bands) = Stationery::Text::Exclusions.new(bands)

  def wrap(source, width, style: base_style, **)
    described_class.new(book).wrap(Stationery::Text::Markup.parse(source, style), width, **)
  end

  it "gives lines beside a left float the narrower width and its offset, and the full width below it" do
    lines = wrap(words, 200, exclusions: exclusions(band(0, line_height * 2, 80, 0)))

    expect(lines.first(2).map(&:offset)).to eq([80, 80])
    expect(lines.first(2).map(&:available)).to eq([120, 120])
    expect(lines.drop(2).map(&:offset).uniq).to eq([0])
    expect(lines.drop(2).map(&:available).uniq).to eq([200])
    lines.each { |line| expect(line.width).to be <= line.available + 0.001 }
    expect(lines[2].width).to be > 120
  end

  it "keeps the offset at zero beside a right float" do
    lines = wrap(words, 200, exclusions: exclusions(band(0, line_height, 0, 90)))

    expect(lines.map(&:offset).uniq).to eq([0])
    expect(lines.map(&:available).first(2)).to eq([110, 200])
  end

  it "flows between a left and a right float" do
    lines = wrap(words, 200, exclusions: exclusions(band(0, line_height * 2, 50, 0), band(0, line_height, 0, 60)))

    expect(lines.first(3).map { |line| [line.offset, line.available] }).to eq([[50, 90], [50, 150], [0, 200]])
  end

  it "counts the leading between lines when it finds a line's top" do
    bands = exclusions(band(0, (line_height * 2) + 5, 80, 0))

    expect(wrap(words, 200, exclusions: bands).map(&:offset).first(4)).to eq([80, 80, 80, 0])
    expect(wrap(words, 200, exclusions: bands, leading: 6).map(&:offset).first(4)).to eq([80, 80, 0, 0])
  end

  it "finds the top of a line from the heights of the lines above it, whatever their styles" do
    tall = line_height(20)
    lines = wrap("<font size='20'>big</font>\n#{words}", 200, exclusions: exclusions(band(0, tall + 1, 80, 0)))

    expect(lines.first.height).to be_within(0.001).of(tall)
    expect(lines.map(&:offset).first(3)).to eq([80, 80, 0])
  end

  it "starts a band part of the way down" do
    lines = wrap(words, 200, exclusions: exclusions(band(line_height * 2, line_height * 3, 0, 100)))

    expect(lines.map(&:available).first(4)).to eq([200, 200, 100, 200])
  end

  it "hyphenates and breaks long words to the width of the line they are on" do
    style = base_style(hyphenate: :en)
    lines = wrap("internationalization " * 6, 200, style:, exclusions: exclusions(band(0, line_height * 3, 140, 0)))

    lines.each { |line| expect(line.width).to be <= line.available + 0.001 }
    expect(lines.first.text).to end_with("-")
    expect(lines.map(&:text).join.delete("- ")).to eq("internationalization" * 6)
  end

  it "wraps the lines from `free_from` on as if the floats were gone" do
    bands = exclusions(band(0, line_height * 4, 80, 0))
    beside = wrap(words, 200, exclusions: bands)
    freed = wrap(words, 200, exclusions: bands, free_from: 2)

    expect(freed.first(2).map(&:text)).to eq(beside.first(2).map(&:text))
    expect(freed.drop(2).map(&:offset).uniq).to eq([0])
    expect(freed.drop(2).map(&:available).uniq).to eq([200])
    expect(freed.map(&:text).join(" ")).to eq(words)
  end

  it "leaves lines without exclusions as they were: no offset and no width of their own" do
    lines = wrap(words, 200)

    expect(lines.map(&:offset).uniq).to eq([0])
    expect(lines.map(&:available).uniq).to eq([nil])
  end
end
