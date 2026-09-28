# frozen_string_literal: true

require "fileutils"
require "tmpdir"

RSpec.describe Stationery::Fonts::FontBook do
  it "returns one Font per file per book, with the face's synthetic flags" do
    book = open_sans_book
    font, face = book.resolve(base_style(weight: :bold))

    expect(book.resolve(base_style(weight: :bold)).first).to equal(font)
    expect(face.path).to end_with("OpenSans-Bold.ttf")
  end

  it "memoises by family, weight and style only" do
    book = open_sans_book
    plain = book.resolve(base_style(weight: :bold))

    expect(book.resolve(base_style(weight: :bold, size: 18, color: "#123456", underline: true))).to equal(plain)
    expect(book.resolve(base_style(weight: :bold, style: :italic))).not_to equal(plain)
    expect(book.resolve(base_style(weight: :regular)).last.path).to end_with("OpenSans-Regular.ttf")
  end

  it "falls back to the first registered family for an unknown name and warns once" do
    book = open_sans_book
    2.times { book.resolve(base_style(family: "Nope")) }

    expect(book.resolve(base_style(family: "Nope")).last.path).to end_with("OpenSans-Regular.ttf")
    expect(book.warnings.to_a).to eq([Stationery::Warnings::UnknownFamily.new(requested: "Nope", used: "Open Sans")])
  end

  it "does not warn for registered, bundled or default families" do
    book = open_sans_book
    book.resolve(base_style(family: "Open Sans"))
    book.resolve(base_style(family: "Inter"))

    expect(book.warnings.to_a).to be_empty
  end

  it "resolves a bundled family by name without registering it" do
    expect(open_sans_book.resolve(base_style(family: "Inter")).last.path).to end_with("data/Inter-Regular.ttf")
    expect(open_sans_book.resolve(base_style(family: "Inter", weight: :bold)).last.path).to end_with("Inter-Bold.ttf")
  end

  it "uses bundled Inter when no family is registered at all" do
    font, face = described_class.new.resolve(base_style(family: "default"))

    expect(face.path).to end_with("data/Inter-Regular.ttf")
    expect(font.ttf.postscript_name).to eq("Inter-Regular")
  end

  it "registers a bundled family by name alone and rejects unknown names without paths" do
    book = described_class.new
    book.register("Inter")

    expect(book.families.fetch("Inter").paths[:italic]).to end_with("Inter-Italic.ttf")
    expect { book.register("Nope") }.to raise_error(ArgumentError, /regular face.*bundled: Inter/)
  end

  it "inherits families from a parent book without sharing its Font objects" do
    parent = open_sans_book
    child = described_class.new(parent.families)

    expect(child.resolve(base_style).first).not_to equal(parent.resolve(base_style).first)
  end

  it "re-resolves styles after a family is registered" do
    book = described_class.new
    before = book.resolve(base_style(family: "Custom")).last.path
    book.register("Custom", regular: font_path("OpenSans-Regular.ttf"))

    expect([before, book.resolve(base_style(family: "Custom")).last.path])
      .to eq([book.resolve(base_style(family: "Inter")).last.path, font_path("OpenSans-Regular.ttf")])
  end

  it "resolves faces of a collection by their #N suffix, one Font per face" do
    book = described_class.new
    book.register("Collection", regular: font_path("OpenSans-Collection.ttc"),
                                bold: "#{font_path("OpenSans-Collection.ttc")}#1")
    regular, = book.resolve(base_style(family: "Collection"))
    bold, face = book.resolve(base_style(family: "Collection", weight: :bold))

    expect([regular.ttf.postscript_name, bold.ttf.postscript_name]).to eq(%w[OpenSans-Regular OpenSans-Bold])
    expect(face).to have_attributes(path: end_with(".ttc#1"), synthetic_bold: false)
  end

  it "returns runs it already split for fallback as they are" do
    book = open_sans_book
    split = book.fallback([Stationery::Text::Run.new("a → b", base_style)])

    expect(book.fallback(split)).to equal(split)
    expect(split.map(&:text)).to eq(["a ", "→ ", "b"])
  end

  context "with an installed font pack" do
    let(:dir) { Dir.mktmpdir }

    before do
      FileUtils.mkdir_p(File.join(dir, "liberation_serif"))
      FileUtils.cp(font_path("OpenSans-Italic.ttf"), File.join(dir, "liberation_serif/LiberationSerif-Regular.ttf"))
      Stationery.font_paths << dir
    end

    after do
      Stationery.font_paths.delete(dir)
      FileUtils.rm_rf(dir)
    end

    it "resolves the pack by name before falling back to the first registered family" do
      expect(open_sans_book.resolve(base_style(family: "Liberation Serif")).last.path)
        .to eq(File.join(dir, "liberation_serif/LiberationSerif-Regular.ttf"))
    end

    it "still rejects an unknown family without paths, naming bundled and installable options" do
      expect { described_class.new.register("Nope") }
        .to raise_error(ArgumentError, /regular face.*bundled: Inter.*stationery fonts install.*noto_sans/)
    end
  end
end
