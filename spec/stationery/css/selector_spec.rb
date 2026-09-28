# frozen_string_literal: true

RSpec.describe Stationery::CSS::Selector do
  def element(markup) = Stationery::SVG::Parser.parse(markup)

  it "reads element, class, id and universal selectors with their specificity" do
    expect(described_class.parse("path").specificity).to eq([0, 0, 1])
    expect(described_class.parse(".a.b").specificity).to eq([0, 2, 0])
    expect(described_class.parse("#x").specificity).to eq([1, 0, 0])
    expect(described_class.parse("rect#x.a").specificity).to eq([1, 1, 1])
    expect(described_class.parse("*").specificity).to eq([0, 0, 0])
  end

  it "refuses combinators, pseudo-classes and attribute selectors" do
    ["g path", ".a > .b", "a + b", "a ~ b", "path:hover", "rect[x]", ""].each do |text|
      expect(described_class.parse(text)).to be_nil
    end
  end

  it "matches by name, every class of a class list, and id" do
    rect = element('<rect id="x" class="a  b"/>')

    expect(%w[rect * .a .b .a.b #x rect.a rect#x.a.b].map { |text| described_class.parse(text).match?(rect) })
      .to all(be(true))
    expect(%w[path .c .a.c #y circle.a].map { |text| described_class.parse(text).match?(rect) }).to all(be(false))
  end
end
