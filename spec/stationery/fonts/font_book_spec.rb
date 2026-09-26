# frozen_string_literal: true

RSpec.describe Stationery::Fonts::FontBook do
  it "returns one Font per file per book, with the face's synthetic flags" do
    book = open_sans_book
    font, face = book.resolve(base_style(weight: :bold))

    expect(book.resolve(base_style(weight: :bold)).first).to equal(font)
    expect(face.path).to end_with("OpenSans-Bold.ttf")
  end

  it "falls back to the first registered family and explains when there is none" do
    expect(open_sans_book.resolve(base_style(family: "Nope")).last.path).to end_with("OpenSans-Regular.ttf")
    expect { described_class.new.resolve(base_style) }.to raise_error(Stationery::Error, /font_family/)
  end

  it "inherits families from a parent book without sharing its Font objects" do
    parent = open_sans_book
    child = described_class.new(parent.families)

    expect(child.resolve(base_style).first).not_to equal(parent.resolve(base_style).first)
  end
end
