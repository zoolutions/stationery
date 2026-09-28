# frozen_string_literal: true

require "stationery/html/document"

# What the source's CSS does to the blocks: marks on the text, a style on each block.
RSpec.describe Stationery::HTML::TreeBuilder::Blocks do
  def rich = Stationery::Rich
  def parse(source, **) = Stationery::HTML.parse(source, **)
  def styled_para(style, *items) = rich::Paragraph.new(inlines: inlines(*items), style:)

  it "gives a paragraph its block style and the text inside it the marks" do
    html = %(<p style="text-align: center; margin-top: 8pt; color: #333">a <b style="color: red">b</b></p>)

    expect(parse(html)).to eq(
      [styled_para({ align: :center, margin_top: 8.0 }, txt("a ", color: "#333"),
                   txt("b", color: "#FF0000", bold: true))]
    )
  end

  it "reads rules from style elements anywhere in the document, by class, id and element" do
    html = <<~HTML
      <style>h2 { text-align: right } .lead { font-size: 14pt }</style>
      <h2>Title</h2><p class="lead" id="intro">Lead</p><p>Body</p>
      <style>#intro { color: green }</style>
    HTML

    expect(parse(html)).to eq(
      [rich::Heading.new(level: 2, inlines: [txt("Title")], style: { align: :right }),
       para(txt("Lead", size: 14.0, color: "#008000")), para("Body")]
    )
  end

  it "hands text-align down to the blocks inside a container, which a block of its own overrides" do
    html = %(<div style="text-align: center">loose<p>p</p><h3>h</h3><p style="text-align: left">own</p></div><p>out</p>)

    expect(parse(html)).to eq(
      [styled_para({ align: :center }, "loose"), styled_para({ align: :center }, "p"),
       rich::Heading.new(level: 3, inlines: [txt("h")], style: { align: :center }),
       styled_para({ align: :left }, "own"), para("out")]
    )
  end

  it "makes a container with a box of its own a block, and flattens one without" do
    html = %(<div style="background-color: #eee; padding: 4pt; text-align: right"><p>in</p></div>) +
           %(<div class="x">flat</div>)

    expect(parse(html)).to eq(
      [rich::Container.new(blocks: [styled_para({ align: :right }, "in")],
                           style: { background: "#EEE", padding: [4.0, 4.0, 4.0, 4.0] }),
       para("flat")]
    )
  end

  it "switches a mark off inside an element that has it" do
    html = %(<b>bold <span style="font-weight: normal">not</span></b> <u style="text-decoration: none">still</u>)

    # the element's own mark is applied after its style, so a u stays underlined
    expect(parse(html).first.inlines.map { |inline| [inline.text, inline.marks] }).to eq(
      [["bold ", { bold: true }], ["not", { bold: false }], [" ", {}],
       ["still", { underline: true, strike: false }]]
    )
  end

  it "floats an image by its style or its align attribute, with the margins it is given" do
    html = <<~HTML
      <p><img src="a.png" style="float: left; margin: 0 8pt 4pt 0; width: 40%">Beside</p>
      <img src="b.png" align="right" style="margin-top: 2pt">
      <img src="c.png" style="margin: 3pt">
    HTML

    expect(parse(html)).to eq(
      [rich::Image.new(src: "a.png", alt: nil, width: nil, height: nil,
                       style: { width: 0.4, float: :left, margin: [0.0, 8.0, 4.0, 0.0] }),
       para("Beside"),
       rich::Image.new(src: "b.png", alt: nil, width: nil, height: nil, style: { float: :right, margin_top: 2.0 }),
       rich::Image.new(src: "c.png", alt: nil, width: nil, height: nil, style: {})]
    )
  end

  it "styles block quotes, lists, code blocks and images" do
    html = <<~HTML
      <blockquote style="background-color: #fee; margin: 4pt 0">q</blockquote>
      <ul style="margin-top: 6pt"><li style="color: blue">i</li></ul>
      <pre style="padding: 2pt">c</pre>
      <p style="text-align: center"><img src="a.png" style="width: 50%"></p>
      <img src="b.png" width="10" style="width: 40px; height: 9px">
    HTML

    expect(parse(html)).to eq(
      [rich::Blockquote.new(blocks: [para("q")], style: { background: "#FEE", margin: [4.0, 0.0, 4.0, 0.0] }),
       rich::List.new(ordered: false, start: nil, items: [[para(txt("i", color: "#0000FF"))]],
                      style: { margin_top: 6.0 }),
       rich::CodeBlock.new(text: "c", language: nil, style: { padding: [2.0, 2.0, 2.0, 2.0] }),
       rich::Image.new(src: "a.png", alt: nil, width: nil, height: nil, style: { width: 0.5, align: :center }),
       rich::Image.new(src: "b.png", alt: nil, width: 10, height: nil, style: { width: 30.0 })]
    )
  end

  it "styles tables and their cells" do
    html = <<~HTML
      <style>td.n { text-align: right; width: 60px } table { border: 1px solid #ccc; width: 100% }</style>
      <table><tr><th style="width: 120px; background-color: #eee">Item</th><th class="n">Qty</th></tr>
      <tr><td style="border: none; padding: 2pt">a</td><td class="n" align="left">1</td></tr></table>
    HTML
    table = parse(html).first

    expect(table.style).to eq(border: { width: 0.75, color: "#CCC" }, width: 1.0)
    expect(table.rows.flatten.map { |cell| [cell.align, cell.style] }).to eq(
      [[nil, { width: 90.0, background: "#EEE" }], [nil, {}],
       [nil, { border: { width: 0 }, padding: [2.0, 2.0, 2.0, 2.0] }], [:right, { width: 45.0 }]]
    )
  end

  it "keeps page-break rules on the block they are written on" do
    html = %(<h1 style="page-break-before: always">T</h1><div style="break-inside: avoid"><p>a</p></div>)

    expect(parse(html)).to eq(
      [rich::Heading.new(level: 1, inlines: [txt("T")], style: { break_before: true }),
       rich::Container.new(blocks: [para("a")], style: { keep_together: true })]
    )
  end

  it "tells the report what it did not read" do
    report = Stationery::HTML::Css::Report.new
    parse(%(<style>a > b { color: red } p { display: flex }</style><p style="float: left; color: url(x)">x</p>),
          css: report)

    expect(report.properties).to eq(["display", "float", "color: url(x)"])
    expect(report.selectors).to eq(["a > b"])
  end

  it "parses a document without styles into the same blocks as before" do
    html = File.read(File.expand_path("../../../fixtures/html/trix.html", __dir__))
    report = Stationery::HTML::Css::Report.new
    blocks = parse(html, css: report)

    expect(report.any?).to be(false)
    expect(blocks.grep_v(rich::Rule).map(&:style).uniq).to eq([{}])
  end
end
