# frozen_string_literal: true

RSpec.describe Stationery::Text::Wrapper do
  let(:book) { open_sans_book }

  def lines(source, width, style: base_style)
    runs = Stationery::Text::Markup.parse(source, style)
    described_class.new(book).wrap(runs, width).map { |line| line.fragments.map(&:text).join }
  end

  def width_of(text, style: base_style)
    book.resolve(style).first.width_of(text, style.size, kerning: style.kerning)
  end

  it "keeps text that fits on one line" do
    expect(lines("Hello world", 1000)).to eq(["Hello world"])
  end

  it "breaks at spaces, dropping the space at the break" do
    expect(lines("alpha beta gamma", width_of("alpha beta") + 1)).to eq(["alpha beta", "gamma"])
  end

  it "breaks after a hyphen" do
    expect(lines("well-known", width_of("well-known") - 1)).to eq(["well-", "known"])
  end

  it "force-breaks a word longer than the line" do
    result = lines("Supercalifragilistic", width_of("Supercali"))

    expect(result.size).to be > 1
    expect(result.join).to eq("Supercalifragilistic")
    result.each { |line| expect(width_of(line)).to be <= width_of("Supercali") + 0.001 }
  end

  it "does not break inside a word that spans styles" do
    expect(lines("<b>Tot</b>al due", width_of("Total") + 2)).to eq(%w[Total due])
  end

  it "honours newlines and keeps blank lines" do
    expect(lines("a\n\nb\n", 1000)).to eq(["a", "", "b", ""])
  end

  it "counts letter spacing when measuring" do
    spaced = base_style(letter_spacing: 5)

    limit = width_of("alpha beta") + 30

    expect(lines("alpha beta", limit)).to eq(["alpha beta"])
    expect(lines("alpha beta", limit, style: spaced)).to eq(%w[alpha beta])
  end

  it "gives a line of mixed sizes the tallest run's metrics" do
    runs = Stationery::Text::Markup.parse("small <font size='20'>BIG</font>", base_style)
    line = described_class.new(book).wrap(runs, 1000).first
    big = book.resolve(base_style(size: 20)).first

    expect(line.ascent).to be_within(0.001).of(big.ascender(20))
    expect(line.height).to be_within(0.001).of(big.line_height(20))
  end

  it "measures each fragment and places it along the line" do
    line = described_class.new(book).wrap(Stationery::Text::Markup.parse("ab <b>cd</b>", base_style), 1000).first

    expect(line.fragments.map(&:x)).to eq([0, width_of("ab ")])
    expect(line.width).to be_within(0.001).of(width_of("ab ") + width_of("cd", style: base_style(weight: :bold)))
  end

  describe "justifiability" do
    def wrapped(source, width)
      described_class.new(book).wrap(Stationery::Text::Markup.parse(source, base_style), width)
    end

    it "marks soft-wrapped lines justifiable, not the last line" do
      result = wrapped("alpha beta gamma", width_of("alpha beta") + 1)

      expect(result.map(&:justifiable?)).to eq([true, false])
    end

    it "does not justify a line ended by a newline" do
      result = wrapped("alpha beta\ngamma delta epsilon", width_of("gamma delta") + 1)

      expect(result.map(&:justifiable?)).to eq([false, true, false])
    end
  end
end
