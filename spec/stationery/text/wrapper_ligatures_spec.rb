# frozen_string_literal: true

require "timeout"

# Words with the ligatures f makes, and how far around a width to look.
module LigatureSamples
  WORDS = %w[ff fi fl ffi ffl office waffle affix fluffy baffling afflict fjord].freeze
  OFFSETS = [-0.05, -0.01, -0.002, 0, 0.002, 0.01, 0.05].freeze
end

# A word is measured whole, ligatures and kerning included, to find that it
# does not fit; it must be broken by that measure too. Measured letter by
# letter, "office" in Open Sans (whose "ffi" is wider than f, f and i) fits
# at a width its ligature does not, and the wrapper went round for ever.
RSpec.describe Stationery::Text::Wrapper do
  let(:book) { open_sans_book }

  def fonts
    book.register("Inter fixture", regular: font_path("Inter-Regular.ttf"))
    book.register("Source Sans", regular: font_path("SourceSans3-Latin.otf"))
    [{ family: "Open Sans" }, { family: "Open Sans", weight: :bold }, { family: "Open Sans", style: :italic },
     { family: "Open Sans", weight: :bold, style: :italic }, { family: "Inter" }, { family: "Inter", weight: :bold },
     { family: "Inter", style: :italic }, { family: "Inter", weight: :bold, style: :italic },
     { family: "Inter fixture" }, { family: "Source Sans" }]
  end

  def style(**) = Stationery::Text::Style.new(size: 10, **)
  def font(style) = book.resolve(style).first
  def whole(text, style) = font(style).width_of(text, style.size, kerning: style.kerning, ligatures: style.ligatures)
  def letters(text, style) = text.each_char.sum { |char| whole(char, style) }

  def wrap(text, width, style)
    Timeout.timeout(2) { described_class.new(book).wrap([Stationery::Text::Run.new(text, style)], width) }
  end

  # Every width between and around the two measures of every head of the word.
  def widths(word, style)
    (1..word.length).flat_map do |count|
      head = word[0, count]
      [whole(head, style), letters(head, style), (whole(head, style) + letters(head, style)) / 2]
        .flat_map { |width| LigatureSamples::OFFSETS.map { |offset| width + offset } }
    end.uniq
  end

  # Nothing lost, and no line wider than its width but a line of one letter.
  def expect_wrapped(lines, text, width)
    expect(lines.map(&:text).join(" ").delete(" ")).to eq(text.delete(" "))
    lines.each do |line|
      next if line.text.length == 1

      expect(line.width).to be <= width + described_class::EPSILON, "#{line.text.inspect} at #{width}"
    end
  end

  it "breaks a word that fits letter by letter but not with its ligature" do
    width = (whole("office", style(family: "Open Sans")) + letters("office", style(family: "Open Sans"))) / 2
    lines = wrap("office", width, style(family: "Open Sans"))

    expect(lines.map(&:text)).to eq(%w[offic e])
    expect_wrapped(lines, "office", width)
  end

  it "keeps a word on its line when it fits as it is drawn" do
    width = whole("office", style(family: "Open Sans")) + 0.0001

    expect(wrap("office", width, style(family: "Open Sans")).map(&:text)).to eq(["office"])
  end

  it "ends and keeps every line within its width for ligature words in every font at widths around them" do
    fonts.product([true, false]).each do |options, ligatures|
      word_style = style(**options, ligatures:)
      LigatureSamples::WORDS.each do |word|
        widths(word, word_style).each { |width| expect_wrapped(wrap(word, width, word_style), word, width) }
      end
    end
  end

  it "ends and keeps every line within its width for ligature words in a sentence" do
    fonts.each do |options|
      sentence_style = style(**options)
      text = "an office for the waffle affix"
      LigatureSamples::WORDS.first(8).each do |word|
        widths(word, sentence_style).each do |width|
          expect_wrapped(wrap(text, width, sentence_style), text, width)
        end
      end
    end
  end
end
