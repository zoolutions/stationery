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

  it "measures each segment once however many words join the line" do
    font = book.resolve(base_style).first
    allow(font).to receive(:width_of).and_call_original
    words = %w[alpha beta gamma delta epsilon zeta eta theta iota kappa]

    lines(words.join(" "), 1000)

    # ten words, one space string shared by nine gaps is nine segments, and the line as a fragment
    expect(font).to have_received(:width_of).exactly(words.size + 9 + 1).times
  end

  it "allocates no String to measure a word without soft hyphens" do
    wrapper = described_class.new(book)
    text = "harbour"

    expect(wrapper.send(:plain, text)).to be(text)
    expect(wrapper.send(:plain, "har\u00ADbour")).to eq("harbour")
  end

  it "does not take a word apart when it cannot be hyphenated" do
    allow(Stationery::Hyphenation).to receive(:points).and_call_original

    expect(lines("alpha beta gamma", width_of("alpha beta") + 1)).to eq(["alpha beta", "gamma"])
    expect(Stationery::Hyphenation).not_to have_received(:points)
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

  describe "hyphenation" do
    let(:german) { base_style(hyphenate: "de") }

    it "is off by default: an overflowing word is broken between characters" do
      expect(lines("Silbentrennung", width_of("Silben-") + 0.5)).to eq(%w[Silbent rennu ng])
    end

    it "breaks a word that does not fit at the longest pattern point that does, drawing a hyphen" do
      expect(lines("Die Silbentrennung", width_of("Die Silben-") + 0.5, style: german))
        .to eq(["Die Silben-", "trennung"])
      expect(lines("Die Silbentrennung", width_of("Die Sil-") + 0.5, style: german))
        .to eq(["Die Sil-", "ben-", "tren-", "nung"])
    end

    it "hyphenates a word alone on its line before breaking characters" do
      expected = join_fitting(["Do-", "nau-", "dampf-", "schiff-", "fahrt"], width_of("Donaudampf-"))

      expect(lines("Donaudampfschifffahrt", width_of("Donaudampf-") + 0.5, style: german)).to eq(expected)
    end

    it "never breaks inside the minimum letters at either end" do
      expect(lines("Silbentrennung", width_of("Sil-") - 0.5, style: german)).not_to include("Si-")
      expect(lines("Silbentrennung", width_of("Silbentrennung") - 0.5, style: german).first).not_to eq("Silbentrennun-")
    end

    it "keeps punctuation around the word out of the patterns" do
      expect(lines("(Silbentrennung),", width_of("(Silben-") + 0.5, style: german))
        .to eq(["(Silben-", "tren-", "nung),"])
    end

    it "marks a hyphenated line justifiable" do
      runs = Stationery::Text::Markup.parse("Die Silbentrennung", german)
      result = described_class.new(book).wrap(runs, width_of("Die Silben-") + 0.5)

      expect(result.map(&:justifiable?)).to eq([true, false])
    end

    # The greedy wrapper takes the longest prefix that fits each time.
    def join_fitting(parts, max)
      parts.each_with_object([]) do |part, out|
        candidate = out.last && "#{out.last.delete_suffix("-")}#{part}"
        if candidate && width_of(candidate) <= max + 0.001 then out[-1] = candidate
        else out << part
        end
      end
    end
  end

  describe "soft hyphens" do
    it "are never measured or drawn while the word fits" do
      result = described_class.new(book).wrap(Stationery::Text::Markup.parse("Zei\u00ADtungsleser", base_style), 1000)

      expect(result.first.fragments.map(&:text)).to eq(["Zeitungsleser"])
      expect(result.first.width).to be_within(0.001).of(width_of("Zeitungsleser"))
    end

    it "name the break points of a word that does not fit and draw a hyphen there" do
      expect(lines("Zei\u00ADtungs\u00ADleser wird", width_of("Zeitungs-") + 0.5)).to eq(["Zeitungs-", "leser", "wird"])
    end

    it "suppress the patterns for that word" do
      result = lines("Silben\u00ADtrennung", width_of("Silben-") + 0.5, style: base_style(hyphenate: "de"))

      expect(result.first).to eq("Silben-")
      expect(result).not_to include("tren-")
      expect(result.join).to eq("Silben-trennung")
    end
  end

  describe "zero-width spaces and CJK" do
    it "breaks at a zero-width space and never draws it" do
      expect(lines("alpha\u200Bbeta gamma", width_of("gamma") + 0.5)).to eq(%w[alpha beta gamma])
      expect(lines("al\u200Bpha", 1000)).to eq(["alpha"])
    end

    it "breaks between ideographic characters" do
      expect(lines("日本語のテキスト", width_of("日本語") + 0.5)).to eq(%w[日本語 のテキ スト])
    end

    it "keeps a closing mark on the line before it and an opening bracket with what follows" do
      expect(lines("「日本」です。", width_of("日本") + 0.5)).to eq(["「日", "本」", "で", "す。"])
    end

    it "breaks between Latin and CJK text in a mixed word" do
      expect(lines("abc漢字def", width_of("abc漢字") + 0.5)).to eq(%w[abc漢字 def])
    end

    it "never hyphenates a CJK unit" do
      allow(Stationery::Hyphenation).to receive(:points).and_call_original

      result = lines("日本語", width_of("日") + 0.5, style: base_style(hyphenate: true))

      expect(result).to eq(%w[日 本 語])
      expect(Stationery::Hyphenation).not_to have_received(:points)
    end

    it "splits a word into break units" do
      expect(Stationery::Text::Breaks.units("東京（とうきょう）"))
        .to eq([["東", false], ["京", false], ["（と", false], ["う", false], ["きょ", false], ["う）", false]])
      expect(Stationery::Text::Breaks.units("hello")).to eq([["hello", false]])
      expect(Stationery::Text::Breaks.units("。")).to eq([["。", true]])
    end
  end

  it "measures each fragment and places it along the line" do
    line = described_class.new(book).wrap(Stationery::Text::Markup.parse("ab <b>cd</b>", base_style), 1000).first

    expect(line.fragments.map(&:x)).to eq([0, width_of("ab ")])
    expect(line.width).to be_within(0.001).of(width_of("ab ") + width_of("cd", style: base_style(weight: :bold)))
  end

  it "cuts text into the tokens String#scan finds: words, hyphens, runs of spaces and tabs, newlines" do
    texts = ["alpha  beta\tgamma\n\ndelta-epsilon--zeta -eta- ", "\n", " ", "-", "", "soft­hy-phen", "a\r\fb"]
    texts.each do |text|
      items = described_class.new(book).send(:items, [Stationery::Text::Run.new(text, base_style)])
      tokens = items.map { |kind, segments| kind == :newline ? "\n" : segments.map(&:text).join }

      expect(tokens).to eq(text.scan(described_class::TOKEN)), text.inspect
    end
  end

  it "keeps a line of one segment as one fragment, and joins a stretch in one style" do
    runs = Stationery::Text::Markup.parse("one <b>two three</b> <i>four</i>", base_style)
    line = described_class.new(book).wrap(runs, 1000).first

    expect(line.fragments.map(&:text)).to eq(["one ", "two three", " ", "four"])
    expect(line.fragments.map { |fragment| fragment.text.frozen? }).to all(be(false))
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
