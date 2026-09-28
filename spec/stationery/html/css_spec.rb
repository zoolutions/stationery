# frozen_string_literal: true

require "stationery/html/document"

RSpec.describe Stationery::HTML::Css do
  def element(name, attributes = {}) = Stationery::HTML::TreeBuilder::Element.new(name, attributes, [])
  def css(*sheets) = described_class.parse(sheets)
  def inline(style, name = "p") = css.resolve(element(name, "style" => style))

  describe "text properties" do
    [
      ["color: #ff0000", { color: "#FF0000" }],
      ["color: #abc", { color: "#ABC" }],
      ["color: Navy", { color: "#000080" }],
      ["color: rgb(1, 2, 300)", { color: "#0102FF" }],
      ["color: rgba(10,20,30,0.5)", { color: "#0A141E" }],
      ["font-size: 16px", { size: 12.0 }],
      ["font-size: 14pt", { size: 14.0 }],
      ["font-size: 1.5em", { scale: 1.5 }],
      ["font-size: 80%", { scale: 0.8 }],
      ["font-size: large", { scale: 1.125 }],
      ["font-size: 2em; font-size: 10pt", { size: 10.0 }],
      ["font-weight: bold", { bold: true }],
      ["font-weight: 600", { bold: true }],
      ["font-weight: 400", { bold: false }],
      ["font-weight: normal", { bold: false }],
      ["font-style: italic", { italic: true }],
      ["font-style: normal", { italic: false }],
      ["text-decoration: underline", { underline: true, strike: false }],
      ["text-decoration: underline line-through", { underline: true, strike: true }],
      ["text-decoration: none", { underline: false, strike: false }],
      ["COLOR: red; Font-Weight: BOLD", { color: "#FF0000", bold: true }]
    ].each do |style, marks|
      it "reads #{style.inspect}" do
        expect(inline(style)).to eq([marks, {}])
      end
    end
  end

  describe "block properties" do
    [
      ["text-align: center", { align: :center }],
      ["text-align: JUSTIFY", { align: :justify }],
      ["background-color: #eee", { background: "#EEE" }],
      ["background-color: transparent", {}],
      ["background-color: red; background-color: transparent", {}],
      ["margin: 8px", { margin: [6.0, 6.0, 6.0, 6.0] }],
      ["margin: 8px 0", { margin: [6.0, 0.0, 6.0, 0.0] }],
      ["margin: 1pt 2pt 3pt", { margin: [1.0, 2.0, 3.0, 2.0] }],
      ["margin: 1pt 2pt 3pt 4pt", { margin: [1.0, 2.0, 3.0, 4.0] }],
      ["margin-top: 12pt; margin-bottom: 4px", { margin_top: 12.0, margin_bottom: 3.0 }],
      ["padding: 4px 8px", { padding: [3.0, 6.0, 3.0, 6.0] }],
      ["padding-left: 10pt", { padding_left: 10.0 }],
      ["border: 1px solid #ccc", { border: { width: 0.75, color: "#CCC" } }],
      ["border: #000 2pt dashed", { border: { width: 2.0, color: "#000" } }],
      ["border: none", { border: { width: 0 } }],
      ["width: 200px", { width: 150.0 }],
      ["width: 50%", { width: 0.5 }],
      ["width: 150%", { width: 1.0 }],
      ["width: auto", {}],
      ["page-break-before: always", { break_before: true }],
      ["break-after: page", { break_after: true }],
      ["page-break-before: auto", {}],
      ["break-inside: avoid", { keep_together: true }],
      ["page-break-inside: avoid", { keep_together: true }],
      ["column-count: 3", { columns: 3 }],
      ["columns: 2; column-gap: 16px", { columns: 2, column_gap: 12.0 }],
      ["column-count: 2; column-count: auto", {}],
      ["column-gap: 10pt; column-gap: normal", {}]
    ].each do |style, block|
      it "reads #{style.inspect}" do
        expect(inline(style)).to eq([{}, block])
      end
    end
  end

  describe "what is not read" do
    it "reports unknown properties once and values a property does not take" do
      sheet = css
      sheet.resolve(element("p", "style" => "float: left; color: url(x.png); margin: 1em; float: right"))
      sheet.resolve(element("p", "style" => "float: left; width: auto; font-size: big; text-align: start"))

      expect(sheet.report.properties).to eq(
        ["float", "color: url(x.png)", "margin: 1em", "font-size: big", "text-align: start"]
      )
    end

    it "reports selectors with combinators and skips at-rules" do
      sheet = css("@import url(evil.css); div > p { color: red } ul li, a:hover { color: blue } p { color: green }")

      expect(sheet.report.selectors).to eq(["div > p", "ul li", "a:hover"])
      expect(sheet.resolve(element("p"))).to eq([{ color: "#008000" }, {}])
      expect(sheet.report.any?).to be(true)
    end

    it "has nothing to report for a document without styles" do
      sheet = css
      sheet.resolve(element("p", "class" => "lead"))

      expect(sheet.report.any?).to be(false)
      expect(sheet.resolve(element("div"))).to eq([{}, {}])
    end
  end

  describe "the cascade" do
    let(:sheet) do
      css("p { color: black; text-align: left } .lead { color: blue; font-size: 14pt } #intro { color: green }",
          "p.lead { text-align: right } p { margin-top: 3pt }")
    end

    it "lets the more specific rule win, then the later one" do
      marks, block = sheet.resolve(element("p", "class" => "lead", "id" => "intro"))

      expect(marks).to eq(color: "#008000", size: 14.0)
      expect(block).to eq(align: :right, margin_top: 3.0)
    end

    it "lets the inline style win over every rule" do
      marks, block = sheet.resolve(element("p", "id" => "intro", "style" => "color: red; text-align: center"))

      expect(marks).to eq(color: "#FF0000")
      expect(block).to eq(align: :center, margin_top: 3.0)
    end

    it "reads the font element's attributes and center, overridable by a style" do
      expect(css.resolve(element("font", "color" => "red",
                                         "size" => "5"))).to eq([{ color: "#FF0000", scale: 1.5 }, {}])
      expect(css.resolve(element("font", "color" => "red", "style" => "color: blue")).first).to eq(color: "#0000FF")
      expect(css.resolve(element("center"))).to eq([{}, { align: :center }])
    end
  end
end
