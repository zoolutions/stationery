# frozen_string_literal: true

require "support/fake_shapers"

# Words the fast path takes, texts it leaves to the wrapper, and styles.
module OneWordSamples
  WORDS = ["Stockholm", "fine", "42", "1,234.50", "x", "W", "AVATAR", "naïve", "coöperate", "A&B", "a_b", "a/b",
           "non breaking", " ", " ", "a b", "☃", "é", "(7)", "€12", "don’t"].freeze
  BREAKABLE = ["", " ", "  ", "word ", " word", "two words", "semi-detached", "-", "a-", "-a", "--", "soft­hyphen",
               "­", "zero​width", "​", "日本語", "日本語。", "Tokyo東京", "、", "tab\there", "\t",
               "line\nbreak", "\n", "word\n", "\nword", "\r", "a\rb", "a\fb", "a\vb", "\0", "a\0", "…", "ｱ"].freeze
  STYLES = { "plain" => {}, "kerned" => { kerning: true }, "letter-spaced" => { letter_spacing: 2 },
             "hyphenated" => { hyphenate: :en }, "large" => { size: 20 }, "without ligatures" => { ligatures: false },
             "with features" => { features: %w[smcp tnum] }, "bold italic" => { weight: :bold, style: :italic } }.freeze
  WIDTHS = [1000, 12, 0].freeze
end

# One word that fits its line is wrapped without being taken apart: what most
# cells of a table hold. The line it makes is the line the wrapper makes of
# any text, which every example here compares it with.
RSpec.describe Stationery::Text::Wrapper do
  let(:book) { open_sans_book }

  def run(text, style = base_style) = Stationery::Text::Run.new(text, style)

  def describe_lines(lines)
    lines.map do |line|
      { fragments: line.fragments.map(&:to_h), width: line.width, ascent: line.ascent, descent: line.descent,
        height: line.height, justifiable: line.justifiable?, offset: line.offset, available: line.available }
    end
  end

  # The lines of the wrapper as it is, and of the wrapper taking every text apart.
  def both(runs, width, book: self.book, **)
    general = described_class.new(book)
    allow(general).to receive(:one_word).and_return(nil)
    [described_class.new(book).wrap(runs, width, **), general.wrap(runs, width, **)]
      .map { |lines| describe_lines(lines) }
  end

  # Whether the wrapper took `runs` apart at `width`.
  def taken_apart?(runs, width)
    wrapper = described_class.new(book)
    taken = false
    allow(wrapper).to(receive(:items).and_wrap_original do |items, *args|
      taken = true
      items.call(*args)
    end)
    wrapper.wrap(runs, width, fallback_style: base_style)
    taken
  end

  def width_of(text, style = base_style)
    book.resolve(style).first.width_of(text, style.render_size, letter_spacing: style.letter_spacing,
                                                                kerning: style.kerning, ligatures: style.ligatures,
                                                                features: style.features)
  end

  def allocations
    GC.disable
    before = GC.stat(:total_allocated_objects)
    yield
    GC.stat(:total_allocated_objects) - before
  ensure
    GC.enable
  end

  it "makes one line of one fragment of a word that fits" do
    lines = described_class.new(book).wrap([run("Stockholm")], 200)

    expect(lines.size).to eq(1)
    expect(lines.first.fragments.map(&:text)).to eq(["Stockholm"])
    expect(lines.first.fragments.first.to_h).to include(width: width_of("Stockholm"), x: 0, style: base_style)
    expect(lines.first).not_to be_justifiable
  end

  it "does not take the word apart" do
    wrapper = described_class.new(book)
    runs = [run("Stockholm")]
    wrapper.wrap(runs, 200)

    expect(allocations { 20.times { wrapper.wrap(runs, 200) } }).to be <= 20 * 12
  end

  OneWordSamples::STYLES.each do |name, overrides|
    it "wraps a word as any text is wrapped, #{name}, at every width" do
      style = base_style(**overrides)
      (OneWordSamples::WORDS + OneWordSamples::BREAKABLE).each do |text|
        fits = width_of(text, style)
        [Float::INFINITY, 1000, fits + 1, fits, fits - 0.00005, fits - 0.001, fits / 2, 3, 0].each do |width|
          fast, general = both([run(text, style)], width)

          expect(fast).to eq(general), "#{text.inspect} at #{width}"
        end
      end
    end
  end

  it "leaves text that can break, and a word that does not fit, to the wrapper" do
    OneWordSamples::BREAKABLE.each { |text| expect(taken_apart?([run(text)], 1000)).to be(true), text.inspect }
    expect(taken_apart?([run("Stockholm")], width_of("Stockholm") - 0.001)).to be(true)
    expect(taken_apart?([run("Stock"), run("holm", base_style(weight: :bold))], 1000)).to be(true)
    expect(taken_apart?([], 1000)).to be(true)
  end

  it "takes every word that cannot break and fits" do
    OneWordSamples::WORDS.each { |text| expect(taken_apart?([run(text)], 1000)).to be(false), text.inspect }
    expect(taken_apart?([run("Stockholm")], width_of("Stockholm") - 0.00005)).to be(false)
  end

  it "wraps markup, several runs and no run as any text is wrapped" do
    sources = ["<b>Total</b>", "<b>Tot</b>al", "<i>a</i> <b>b</b>", "A&amp;B", "<a href='https://example.com'>link</a>",
               "x<sup>2</sup>", ""]
    sources.each do |source|
      runs = Stationery::Text::Markup.parse(source, base_style)
      OneWordSamples::WIDTHS.each do |width|
        fast, general = both(runs, width, fallback_style: base_style)

        expect(fast).to eq(general), "#{source.inspect} at #{width}"
      end
    end
  end

  it "takes the metrics of the line from the word, not from the style of the paragraph" do
    fast, general = both([run("Total", base_style(size: 20))], 1000, fallback_style: base_style(size: 6))

    expect(fast).to eq(general)
    expect(fast.first[:height]).to eq(book.resolve(base_style).first.line_height(20))
  end

  it "wraps a word beside a float as any text is wrapped" do
    band = Stationery::Text::Exclusions::Band.new(top: 0, bottom: 30, left: 40, right: 10)
    exclusions = Stationery::Text::Exclusions.new([band])
    [200, 60, 50].each do |width|
      fast, general = both([run("Stockholm")], width, exclusions:, leading: 2)

      expect(fast).to eq(general)
      expect(fast.first).to include(offset: 40, available: width - 50)
    end
  end

  it "measures a word with the shaper of the book" do
    [FakeShapers::WIDE, FakeShapers::REVERSED, FakeShapers::LIGATING, FakeShapers::DECLINING].each do |shaper|
      shaped = Stationery::Fonts::FontBook.new(book.families, shaper:)
      plain = width_of("finish")
      [1000, plain * 2, (plain * 2) - 0.001, plain, 10].each do |width|
        fast, general = both([run("finish")], width, book: shaped)

        expect(fast).to eq(general)
      end
    end
  end

  it "has nothing left of a word after its line" do
    wrapper = described_class.new(book)
    general = described_class.new(book)
    allow(general).to receive(:one_word).and_return(nil)

    expect(wrapper.rest([run("Stockholm")], 200, 1)).to eq([])
    expect(wrapper.rest([run("Stockholm")], 20, 1)).to eq(general.rest([run("Stockholm")], 20, 1))
    expect(wrapper.wrap([run("Stockholm")], 200).size).to eq(1)
  end

  it "wraps a word again after a text that broke" do
    wrapper = described_class.new(book)
    wrapper.wrap([run("alpha beta\n")], 30)
    lines = wrapper.wrap([run("Stockholm")], 200)

    expect(describe_lines(lines)).to eq(describe_lines(described_class.new(book).wrap([run("Stockholm")], 200)))
  end
end
