# frozen_string_literal: true

# What a paragraph has left after its first lines: the runs a page break
# carries over to a place of another width.
RSpec.describe Stationery::Text::Wrapper do
  let(:book) { open_sans_book }

  def parse(source, style = base_style) = Stationery::Text::Markup.parse(source, style)
  def wrapper = described_class.new(book)
  def texts(lines) = lines.map(&:text)

  def width_of(text, style: base_style)
    book.resolve(style).first.width_of(text, style.size, kerning: style.kerning)
  end

  # The lines after the first `count` at `width`, wrapped again at `other`.
  def again(source, width, count, other, style: base_style, **)
    rest = wrapper.rest(parse(source, style), width, count, **)
    texts(wrapper.wrap(rest, other, fallback_style: style))
  end

  it "is everything when no line is taken" do
    runs = parse("alpha beta gamma")

    expect(wrapper.rest(runs, 40, 0)).to eq(runs)
  end

  it "is nothing when every line is taken" do
    expect(wrapper.rest(parse("alpha beta"), 1000, 1)).to eq([])
    expect(wrapper.rest(parse("alpha beta"), 1000, 5)).to eq([])
  end

  it "starts after the space a line broke at" do
    expect(again("alpha beta gamma delta", width_of("alpha beta") + 1, 1, 1000)).to eq(["gamma delta"])
  end

  it "starts after the newline that ended a line, and keeps the newlines that follow" do
    expect(again("one\ntwo\n\nthree four", 1000, 1, 1000)).to eq(["two", "", "three four"])
  end

  it "keeps the styles of what is left" do
    rest = wrapper.rest(parse("alpha <b>beta gamma</b> delta"), width_of("alpha") + 1, 1)

    expect(rest.map(&:text).join).to eq("beta gamma delta")
    expect(rest.map { |run| run.style.weight }).to eq(%i[bold regular])
  end

  it "puts a hyphenated word together again, less the part that stayed" do
    style = base_style(hyphenate: :en)
    narrow = texts(wrapper.wrap(parse("internationalization of things", style), 60))

    expect(narrow.first).to end_with("-")
    expect(again("internationalization of things", 60, 1, 1000, style:))
      .to eq(["internationalization of things".delete_prefix(narrow.first.chomp("-"))])
  end

  it "keeps the soft hyphens of what is left, which still break there and draw nothing otherwise" do
    source = "extra­ordinary cir­cum­stances"
    width = width_of("extra-") + 1

    expect(texts(wrapper.wrap(parse(source), width)).first).to eq("extra-")
    expect(again(source, width, 1, 1000)).to eq(["ordinary circumstances"])
    expect(again(source, width, 1, width_of("ordinary cir-") + 1)).to eq(["ordinary cir-", "cumstances"])
  end

  it "carries the characters of a word broken because it is wider than the line" do
    narrow = texts(wrapper.wrap(parse("Supercalifragilistic end"), width_of("Supercali")))

    expect(again("Supercalifragilistic end", width_of("Supercali"), 1, 1000))
      .to eq(["Supercalifragilistic end".delete_prefix(narrow.first)])
  end

  it "starts after a hyphen, a zero-width space or a CJK character a line broke at" do
    expect(again("well-known fact", width_of("well-") + 1, 1, 1000)).to eq(["known fact"])
    expect(again("alpha​beta​gamma", width_of("alpha") + 1, 1, 1000)).to eq(["betagamma"])
    expect(again("alpha​beta​gamma", width_of("alpha") + 1, 1, width_of("gamma") + 1)).to eq(%w[beta gamma])
    expect(again("日本語の文章", width_of("日本語") + 1, 1, 1000)).to eq(["の文章"])
  end

  it "counts the lines as they were wrapped beside floats" do
    band = Stationery::Text::Exclusions::Band.new(top: 0, bottom: line_height * 2, left: 120, right: 0)
    exclusions = Stationery::Text::Exclusions.new([band])
    words = Array.new(30) { |i| "word#{i}" }.join(" ")
    beside = texts(wrapper.wrap(parse(words), 200, exclusions:))

    expect(again(words, 200, 2, 1000, exclusions:)).to eq([words.delete_prefix("#{beside.first(2).join(" ")} ")])
  end

  it "wraps as before once it has been asked for a rest" do
    subject = wrapper
    subject.rest(parse("alpha beta gamma"), width_of("alpha") + 1, 1)

    expect(texts(subject.wrap(parse("alpha beta gamma"), width_of("alpha beta") + 1))).to eq(["alpha beta", "gamma"])
  end
end
