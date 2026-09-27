# frozen_string_literal: true

RSpec.describe Stationery::Fonts::Fallback do
  let(:run_class) { Stationery::Text::Run }

  def book_with(*fallbacks, **families)
    book = Stationery::Fonts::FontBook.new(open_sans_book.families, fallbacks:)
    families.each { |name, path| book.register(name.to_s, regular: path) }
    book
  end

  def apply(text, book: book_with, **style)
    described_class.new(book).apply([run_class.new(text, base_style(**style))])
  end

  it "uses fixtures with a real gap: Open Sans lacks the arrow, Inter has it, nothing has the snowman" do
    open_sans = open_sans_book.resolve(base_style).first
    inter = open_sans_book.resolve(base_style(family: "Inter")).first

    expect([open_sans.glyph?("→"), inter.glyph?("→")]).to eq([false, true])
    expect([open_sans.glyph?("☃"), inter.glyph?("☃")]).to eq([false, false])
  end

  it "splits a run at a missing glyph into primary and bundled Inter runs, keeping the rest of the style" do
    runs = apply("a→b", size: 12, color: "#ff0000")

    expect(runs.map(&:text)).to eq(%w[a → b])
    expect(runs.map { |run| run.style.family }).to eq(["Open Sans", "Inter", "Open Sans"])
    expect(runs.map { |run| run.style.with(family: "Open Sans") }.uniq).to eq([base_style(size: 12, color: "#ff0000")])
  end

  it "keeps whitespace and joiners with the previous character's family" do
    runs = apply("a →‍→ b")

    expect(runs.map(&:text)).to eq(["a ", "→‍→ ", "b"])
  end

  it "gives leading whitespace and marks the first following family" do
    runs = apply(" ́→a")

    expect(runs.map(&:text)).to eq([" ́→", "a"])
    expect(runs.first.style.family).to eq("Inter")
  end

  it "resolves the fallback's bold face for a bold run" do
    book = book_with
    runs = described_class.new(book).apply([run_class.new("→", base_style(weight: :bold))])

    expect(book.resolve(runs.first.style).last.path).to end_with("Inter-Bold.ttf")
  end

  it "walks the fallbacks in order before bundled Inter" do
    copy = font_path("Inter-Regular.ttf")

    expect(apply("→", book: book_with("Copy", "Inter", Copy: copy)).first.style.family).to eq("Copy")
    expect(apply("→", book: book_with("Inter", "Copy", Copy: copy)).first.style.family).to eq("Inter")
    expect(apply("→", book: book_with("Source", "Copy", Source: font_path("SourceSans3-Latin.otf"), Copy: copy))
             .first.style.family).to eq("Copy")
  end

  it "keeps whitespace no font has with its neighbours instead of hunting for a font" do
    runs = apply("a\u3000b\u202Fc")

    expect(runs.map { |run| [run.text, run.style.family] }).to eq([["a\u3000b\u202Fc", "Open Sans"]])
  end

  it "keeps a glyph no font has in the primary family" do
    runs = apply("a☃b")

    expect(runs.map { |run| [run.text, run.style.family] }).to eq([["a☃b", "Open Sans"]])
  end

  it "returns runs whose glyphs are all present as the same objects" do
    runs = [run_class.new("plain\ntext", base_style), run_class.new("more", base_style(weight: :bold))]

    expect(described_class.new(book_with).apply(runs)).to all(satisfy { |run| runs.any? { |kept| kept.equal?(run) } })
  end

  it "is idempotent" do
    book = book_with
    once = book.fallback([run_class.new("a → b ☃", base_style)])

    expect(book.fallback(once)).to eq(once)
  end

  it "counts drawn missing glyphs once per occurrence" do
    doc = SpecDocument.build { text "☃ and ☃" }
    doc.to_pdf

    expect(doc.warnings.to_a).to eq([Stationery::Warnings::MissingGlyph.new(char: "☃", family: "Open Sans", count: 2)])
  end

  describe "in a document" do
    it "draws the missing glyph from bundled Inter and keeps the text extractable" do
      pdf = SpecDocument.build { text "a → b" }.to_pdf

      expect(text_of(pdf)).to eq("a → b")
      expect(pdf).to include("+OpenSans-Regular").and include("+Inter-Regular")
    end

    it "honours the configured fallback order and inherits it" do
      doc = Class.new(SpecDocument) do
        font_family "Source", regular: "#{SpecDocument::FONTS}/SourceSans3-Latin.otf"
        font_fallbacks "Source", "Inter"
        def view_template = text("a → b")
      end
      subclass = Class.new(doc)

      expect(subclass.config[:fallbacks]).to eq(%w[Source Inter])
      pdf = subclass.new.to_pdf
      expect(pdf).to include("+Inter-Regular")
      expect(pdf).not_to include("+SourceSans")
      expect(SpecDocument.config[:fallbacks]).to eq([])
    end

    it "draws whitespace no font has as a blank of its width, without a warning" do
      doc = SpecDocument.build { text "a\u3000b" }
      pdf = doc.to_pdf
      book = open_sans_book
      font = book.resolve(base_style).first
      line = Stationery::Text::Paragraph.new([run_class.new("a\u3000b", base_style)], book:, width: 200).lines.first

      expect(doc.warnings.to_a).to be_empty
      expect(text_of(pdf)).to match(/\Aa\s+b\z/)
      expect(pdf).not_to include("+Inter-Regular")
      expect(line.width).to be_within(1e-6).of(font.width_of("ab", 10, kerning: true) + 10)
    end

    it "covers table cells" do
      pdf = SpecDocument.build { table([["x → y"]]) }.to_pdf

      expect(pdf).to include("+Inter-Regular")
    end
  end
end
