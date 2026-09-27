# frozen_string_literal: true

RSpec.describe Stationery::Fonts::FontBook do
  it "returns one Font per file per book, with the face's synthetic flags" do
    book = open_sans_book
    font, face = book.resolve(base_style(weight: :bold))

    expect(book.resolve(base_style(weight: :bold)).first).to equal(font)
    expect(face.path).to end_with("OpenSans-Bold.ttf")
  end

  it "falls back to the first registered family for an unknown name" do
    expect(open_sans_book.resolve(base_style(family: "Nope")).last.path).to end_with("OpenSans-Regular.ttf")
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
end
