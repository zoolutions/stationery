# frozen_string_literal: true

# The characters of a text no glyph stands for, found without making a String
# of every character: what the missing-glyph warnings and the split into
# fallback fonts ask for every fragment and every run.
RSpec.describe Stationery::Fonts::Fallback, ".each_missing" do
  let(:book) { open_sans_book }
  let(:font) { book.resolve(base_style).first }

  # Texts with characters the font has, characters it lacks and characters
  # something carries (whitespace, marks, joiners, soft hyphens, selectors).
  def texts
    ["Stockholm", "", " ", "\t\n", "a b", "non breaking", "é", "́", "​‌‍",
     "soft­hyphen", "️", "→", "☃", "a→b☃c", "☃☃", "日本語", "😀", "\u{1F600}x", "ｱ", " ",
     "a b", "ﬁ", "ǅ", "Ω", "ﬀ", "€12", "x\0y", "\u{10FFFF}"]
  end

  # What the walk over every character found.
  def reference(text, font)
    text.each_char.reject { |char| described_class.carried?(char) || font.glyph?(char) }
  end

  def missing(text, font = self.font)
    [].tap { |chars| described_class.each_missing(text, font) { |char| chars << char } }
  end

  def allocations
    GC.disable
    before = GC.stat(:total_allocated_objects)
    yield
    GC.stat(:total_allocated_objects) - before
  ensure
    GC.enable
  end

  it "yields exactly the characters the walk over every character yields, in order, once per occurrence" do
    texts.each do |text|
      expect(missing(text)).to eq(reference(text, font)), text.inspect
    end
  end

  it "finds the same characters in every font" do
    inter = book.resolve(base_style(family: "Inter")).first
    texts.each do |text|
      expect(missing(text, inter)).to eq(reference(text, inter)), text.inspect
    end
  end

  it "reads US-ASCII text, and refuses other encodings as the walk did" do
    ascii = "Stockholm 42".encode(Encoding::US_ASCII)
    latin = "caf\xE9".dup.force_encoding(Encoding::ISO_8859_1)
    utf16 = "a→b".encode(Encoding::UTF_16LE)

    expect(missing(ascii)).to eq(reference(ascii, font))
    expect { reference(latin, font) }.to raise_error(Encoding::CompatibilityError)
    expect { missing(latin) }.to raise_error(Encoding::CompatibilityError)
    expect { missing(utf16) }.to raise_error(Encoding::CompatibilityError)
    expect { missing("caf\xE9".b) }.to raise_error(Encoding::CompatibilityError)
    expect(missing("cafe".b)).to eq(reference("cafe".b, font))
  end

  it "allocates nothing for a text the font covers" do
    text = "The quick brown fox jumps over the lazy dog, 1234567890 times."
    described_class.each_missing(text, font) { nil }

    expect(allocations { 20.times { described_class.each_missing(text, font) { nil } } }).to be <= 1
    expect(allocations { 20.times { described_class.missing?(text, font) } }).to be <= 1
  end

  it "answers whether a text has a missing character" do
    expect(described_class.missing?("Stockholm", font)).to be(false)
    expect(described_class.missing?("a☃", font)).to be(true)
    expect(described_class.missing?("", font)).to be(false)
    expect(described_class.missing?(" ‍́", font)).to be(false)
    expect(described_class.missing?("Stockholm".encode(Encoding::US_ASCII), font)).to be(false)
    expect { described_class.missing?("caf\xE9".dup.force_encoding(Encoding::ISO_8859_1), font) }
      .to raise_error(Encoding::CompatibilityError)
  end
end
