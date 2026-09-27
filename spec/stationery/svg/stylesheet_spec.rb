# frozen_string_literal: true

RSpec.describe Stationery::SVG::Stylesheet do
  def element(markup) = Stationery::SVG::Parser.parse(markup)

  it "reads rules with comma lists, skipping comments, at-rules and !important" do
    sheet = described_class.parse(<<~CSS)
      /* exported */ @font-face { font-family: X; }
      rect, .a { fill: red; stroke: blue !important }
    CSS

    expect(sheet.declarations(element("<rect/>"))).to eq("fill" => "red", "stroke" => "blue")
    expect(sheet.declarations(element('<path class="a"/>'))).to eq("fill" => "red", "stroke" => "blue")
    expect(sheet.declarations(element("<path/>"))).to eq({})
  end

  it "cascades by specificity, then by order" do
    sheet = described_class.parse(<<~CSS)
      #x { fill: green } .a { fill: red; stroke: red } rect { fill: blue; stroke: blue; opacity: 0.5 }
      .b { stroke: black } * { stroke-width: 2 }
    CSS

    expect(sheet.declarations(element('<rect id="x" class="a b"/>')))
      .to eq("fill" => "green", "stroke" => "black", "opacity" => "0.5", "stroke-width" => "2")
  end

  it "ignores rules with selectors it cannot match, listing them" do
    sheet = described_class.parse("g rect, .a > .b { fill: red } .c { fill: blue }")

    expect(sheet.declarations(element('<rect class="a b c"/>'))).to eq("fill" => "blue")
    expect(sheet.unsupported).to eq(["g rect", ".a > .b"])
  end

  it "is empty without a style element" do
    expect(described_class::EMPTY.declarations(element("<rect/>"))).to eq({})
  end
end
