# frozen_string_literal: true

RSpec.describe Stationery::Text::Line do
  let(:book) { open_sans_book }

  def fragment(text, x: 0)
    font, face = book.resolve(base_style)
    Stationery::Text::Fragment.new(text, base_style, font, face, font.width_of(text, 10), x)
  end

  def fallback = [book.resolve(base_style).first, 10]

  it "is not justifiable unless asked" do
    expect(described_class.new([fragment("a b")], fallback)).not_to be_justifiable
    expect(described_class.new([fragment("a b")], fallback, justifiable: true)).to be_justifiable
  end

  it "counts only U+0020 spaces across fragments, not tabs" do
    line = described_class.new([fragment("a b\tc"), fragment(" d e", x: 20)], fallback)

    expect(line.space_count).to eq(3)
  end
end
