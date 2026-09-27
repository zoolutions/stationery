# frozen_string_literal: true

RSpec.describe Stationery::Rich::Inlines do
  def build(items) = items.map { |item| item == :br ? br : txt(*Array(item).first(1), **(Array(item)[1] || {})) }

  describe ".merge" do
    [
      [[], []],
      [%w[a b], ["ab"]],
      [["a", ["b", { bold: true }], ["c", { bold: true }], "d"], ["a", ["bc", { bold: true }], "d"]],
      [["a", "", ["", { bold: true }], "b"], ["ab"]],
      [["a", :br, :br, "b"], ["a", :br, :br, "b"]],
      [[:br], [:br]]
    ].each do |input, expected|
      it "merges #{input.inspect}" do
        expect(described_class.merge(build(input))).to eq(build(expected))
      end
    end

    it "passes images through without merging across them" do
      picture = image("a.png")

      expect(described_class.merge([txt("a"), picture, txt("b")])).to eq([txt("a"), picture, txt("b")])
    end
  end

  describe ".paragraphs" do
    it "splits paragraphs around images and drops empty ones" do
      picture = image("a.png", "A")

      expect(described_class.paragraphs([txt("a"), txt(" b"), picture, txt(""), picture]))
        .to eq([para("a b"), picture, picture])
    end

    it "normalises each run of inlines before merging" do
      result = described_class.paragraphs([txt("a"), image("x"), txt("b")]) do |run|
        run.map { |inline| inline.with(text: inline.text.upcase) }
      end

      expect(result).to eq([para("A"), image("x"), para("B")])
    end
  end
end
