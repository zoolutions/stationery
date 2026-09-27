# frozen_string_literal: true

RSpec.describe Stationery::SVG::Parser do
  it "reads elements, attributes in either quote and nesting, skipping comments and declarations" do
    root = described_class.parse(%(<?xml version="1.0"?><!-- hi --><svg a="1" b='2'><g><rect/></g></svg>))

    expect(root.name).to eq("svg")
    expect(root.attributes).to eq("a" => "1", "b" => "2")
    expect(root.children.first.children.map(&:name)).to eq(["rect"])
  end

  it "keeps the text of text and tspan elements, whitespace collapsed and entities decoded" do
    root = described_class.parse(<<~SVG)
      <svg><text x="1">
        Fish &amp;
        <tspan>chips&#33;</tspan>  </text><g> ignored </g></svg>
    SVG
    text = root.children.first

    expect(text.children.first).to eq(" Fish & ")
    expect(text.children[1].children).to eq(["chips!"])
    expect(text.children.last).to eq(" ")
    expect(root.children.last.children).to eq([])
  end
end
