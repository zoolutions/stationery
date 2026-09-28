# frozen_string_literal: true

require "stationery/html/document"

RSpec.describe Stationery::HTML::TreeBuilder do
  def parse(source) = Stationery::HTML.parse(source)

  describe "blocks" do
    [
      ["", []],
      ["   \n  ", []],
      ["<p>a</p><p>b</p>", [para("a"), para("b")]],
      ["<p>a<p>b", [para("a"), para("b")]],
      ["<p>a<div>b</div>c", [para("a"), para("b"), para("c")]],
      ["loose <b>top</b> text", [para("loose ", txt("top", bold: true), " text")]],
      ["a<div>b</div>c", [para("a"), para("b"), para("c")]],
      ["<html><body><section><article><header>h</header><footer>f</footer></article></section></body></html>",
       [para("h"), para("f")]],
      ["<h1>One</h1><h3>Three <i>it</i></h3><h6></h6>",
       [heading(1, "One"), heading(3, "Three ", txt("it", italic: true))]],
      ["<h1>a<h2>b", [heading(1, "a"), heading(2, "b")]],
      ["<ul><li>a<li>b</ul>", [bullets([para("a")], [para("b")])]],
      ["<ol start=3><li><p>a</p><p>b</p></li><li>c</li></ol>",
       [numbers(3, [para("a"), para("b")], [para("c")])]],
      ["<ol start=x><li>a</li></ol>", [numbers(1, [para("a")])]],
      ["<ul>stray<li>a<ul><li>b</ul></li></ul>", [bullets([para("a"), bullets([para("b")])])]],
      ["<ul> </ul><ol></ol>", []],
      ["<ul><li>a</li><ul><li>b</li></ul></ul>", [bullets([para("a")], [bullets([para("b")])])]],
      ["<dl><dt>term<dd>definition</dl>", [para("term"), para("definition")]],
      ["<blockquote>quoted <b>text</b><p>more</p></blockquote>",
       [quote(para("quoted ", txt("text", bold: true)), para("more"))]],
      ["<pre>\n  line 1\n    line 2\n</pre>", [code_block("  line 1\n    line 2")]],
      [%(<pre><code class="language-ruby">puts &quot;hi&quot;<br>exit</code></pre>),
       [code_block("puts \"hi\"\nexit", "ruby")]],
      ["<p>a</p><hr><p>b</p>", [para("a"), rule, para("b")]],
      ["a<br>b<br/>c", [para("a", br, "b", br, "c")]],
      [%(<img src="a.png" alt="A" width="10" height="20px">), [image("a.png", "A", width: 10, height: 20)]],
      ["<img alt='no source'>", []],
      [%(<p>before <img src="x.png"> after</p>), [para("before"), image("x.png"), para("after")]],
      ["<font color=red size=5>kept</font> <center>centered</center> <blink>too</blink>",
       [para(txt("kept", color: "#FF0000", scale: 1.5)),
        Stationery::Rich::Paragraph.new(inlines: [txt("centered")], style: { align: :center }), para("too")]],
      ["a</b></div></p>b", [para("ab")]]
    ].each do |source, expected|
      it "parses #{source.inspect}" do
        expect(parse(source)).to eq(expected)
      end
    end
  end

  describe "inline marks" do
    [
      ["<strong>a</strong><b>b</b>", [["ab", { bold: true }]]],
      ["<em>a</em><i>b</i>", [["ab", { italic: true }]]],
      ["<u>a</u><ins>b</ins>", [["ab", { underline: true }]]],
      ["<s>a</s><del>b</del><strike>c</strike>", [["abc", { strike: true }]]],
      ["<code>a</code><kbd>b</kbd>", [["ab", { code: true }]]],
      [%(<a href="https://x.test">x</a><a name="y">y</a>), [["x", { link: "https://x.test" }], ["y", {}]]],
      ["H<sub>2</sub>O x<sup>2</sup>", [["H", {}], ["2", { script: :sub }], ["O x", {}], ["2", { script: :sup }]]],
      [%(<span style="font-weight: bold; font-style:italic">a</span><span style="font-weight:700">b</span>),
       [["a", { bold: true, italic: true }], ["b", { bold: true }]]],
      [%(<span style="color: red">tinted</span><span>plain</span>),
       [["tinted", { color: "#FF0000" }], ["plain", {}]]],
      ["<b>bold <i>both</i></b>", [["bold ", { bold: true }], ["both", { bold: true, italic: true }]]]
    ].each do |source, expected|
      it "marks #{source.inspect}" do
        expect(parse(source)).to eq([para(*expected.map { |text, marks| txt(text, **marks) })])
      end
    end

    it "carries marks from an inline element into blocks inside it" do
      expect(parse("<b><p>x</p></b>")).to eq([para(txt("x", bold: true))])
    end
  end

  describe "whitespace" do
    [
      ["  a \n\t b  ", ["a b"]],
      ["<p>\n  a  <b> b </b>  c\n</p>", ["a ", txt("b ", bold: true), "c"]],
      ["<p>a<b> </b>b</p>", ["a", txt(" ", bold: true), "b"]],
      ["<p>a&nbsp;&nbsp; b&nbsp;</p>", ["a   b "]],
      ["<p>a <br> b</p>", ["a", :br, "b"]],
      ["<p>a<br></p>", ["a"]],
      ["<p>a<br><br></p>", ["a", :br]],
      ["<div><br></div>", [:br]],
      ["<p><b> a </b> </p>", [txt("a", bold: true)]]
    ].each do |source, expected|
      it "collapses #{source.inspect}" do
        expect(parse(source)).to eq([para(*expected.map { |item| item == :br ? br : item })])
      end
    end

    it "keeps whitespace inside pre" do
      expect(parse("<pre>a  b\n\tc</pre>")).to eq([code_block("a  b\n\tc")])
    end
  end

  describe "tables" do
    it "closes cells and rows implicitly" do
      expect(parse("<table><tr><td>a<td>b<tr><td>c</table>")).to eq(
        [table([cell(para("a")), cell(para("b"))], [cell(para("c"))])]
      )
    end

    it "reads header cells, sections and alignment" do
      html = <<~HTML
        <table>
          <thead><tr><th align="right">H1</th><th style="text-align: center">H2</th></tr></thead>
          <tbody><tr><td style="color: red">a</td><td ALIGN="LEFT"><b>b</b></td></tr></tbody>
          <tfoot><tr><td>f</td><td></td></tr></tfoot>
        </table>
      HTML

      expect(parse(html)).to eq(
        [table(
          [cell(para("H1"), header: true, align: :right), cell(para("H2"), header: true, align: :center)],
          [cell(para(txt("a", color: "#FF0000"))), cell(para(txt("b", bold: true)), align: :left)],
          [cell(para("f")), cell]
        )]
      )
    end

    it "adds a row for cells written straight into the table and drops stray text" do
      expect(parse("<table>junk<td>a</td></table><table></table>")).to eq([table([cell(para("a"))])])
    end

    it "keeps a table apart from the paragraph before it" do
      expect(parse("<p>a<table><tr><td>b</td></tr></table>")).to eq([para("a"), table([cell(para("b"))])])
    end
  end

  it "reads a Trix document" do
    html = File.read(File.expand_path("../../fixtures/html/trix.html", __dir__))

    expect(parse(html)).to eq(
      [
        heading(1, "Release notes"),
        para("Hello ", txt("team", bold: true), ",", br, "the build is ", txt("green", italic: true), ".", br, br,
             "Details:"),
        bullets(
          [para("Faster ", txt("renders", link: "https://example.test/perf?a=1&b=2"))],
          [para("Fewer bugs")]
        ),
        quote(para("Ship it.")),
        code_block("bin/deploy\n  --prod"),
        para(br),
        para("Thanks  all")
      ]
    )
  end

  it "never raises on malformed input" do
    [
      "<", "<<>>", "</", "<p", "<p><<b>", "<table><td><tr></table></td>", "<ul><li><ol><li></ul>",
      "&#xZZ; &unknown; &", "<a href='x>y</a>", "<pre>unterminated", "</html></body>text", "<img src=>"
    ].each { |source| expect { parse(source) }.not_to raise_error }
  end
end
