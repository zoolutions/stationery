# frozen_string_literal: true

require "stationery/markdown/document"

RSpec.describe Stationery::Markdown::BlockParser do
  def parse(source) = Stationery::Markdown.parse(source)

  def self.em(text) = txt(text, italic: true)

  def self.parses(group, rows)
    describe group do
      rows.each do |source, expected|
        it("parses #{source.inspect}") { expect(parse(source)).to eq(expected) }
      end
    end
  end

  parses "headings", [
    ["# foo\n## foo\n### foo\n#### foo\n##### foo\n###### foo", (1..6).map { |level| heading(level, "foo") }],
    ["####### foo\n\n#5 bolt\n\n\\# escaped", [para("####### foo"), para("#5 bolt"), para("# escaped")]],
    ["# foo *bar* \\*baz\\*", [heading(1, "foo ", em("bar"), " *baz*")]],
    ["## foo ##\n  ### bar    ###\n# #\n#", [heading(2, "foo"), heading(3, "bar"), heading(1), heading(1)]],
    ["Foo *bar*\n=========\n\nFoo\nbaz\n---", [heading(1, "Foo ", em("bar")), heading(2, "Foo baz")]]
  ]

  parses "thematic breaks", [
    ["***\n---\n___\n - - -\n* * *", [rule, rule, rule, rule, rule]],
    ["Foo\n***\nbar", [para("Foo"), rule, para("bar")]],
    ["--\n**", [para("-- **")]]
  ]

  parses "paragraphs", [
    ["", []],
    ["aaa\nbbb\n\n\nccc", [para("aaa bbb"), para("ccc")]],
    ["  aaa\n     bbb   ", [para("aaa bbb")]],
    ["<div>\n*x*\n</div>", [para("<div> ", em("x"), " </div>")]],
    ["Paragraph\n2. not a list\n*\n1) list", [para("Paragraph 2. not a list *"), numbers(1, [para("list")])]]
  ]

  parses "code", [
    ["```ruby\ndef x\n  1\nend\n```", [code_block("def x\n  1\nend", "ruby")]],
    ["~~~~ python extra\na\n~~~\n~~~~~\nafter", [code_block("a\n~~~", "python"), para("after")]],
    ["  ```\n  indented\n    more\n```", [code_block("indented\n  more")]],
    ["```\nunclosed", [code_block("unclosed")]],
    ["    a simple\n      indented code\n\n    more\n\nafter",
     [code_block("a simple\n  indented code\n\nmore"), para("after")]],
    ["para\n    not code", [para("para not code")]]
  ]

  parses "blockquotes", [
    ["> # Foo\n> bar\n> baz", [quote(heading(1, "Foo"), para("bar baz"))]],
    ["> foo\nbar\n---", [quote(para("foo bar")), rule]],
    ["> a\n>> b", [quote(para("a"), quote(para("b")))]],
    [">foo\n\n> bar", [quote(para("foo")), quote(para("bar"))]],
    ["> - a\n> - b", [quote(bullets([para("a")], [para("b")]))]]
  ]

  parses "lists", [
    ["- a\n- b\n* c", [bullets([para("a")], [para("b")]), bullets([para("c")])]],
    ["1. a\n2. b\n\n3) c", [numbers(1, [para("a")], [para("b")]), numbers(3, [para("c")])]],
    ["- a\n  - b\n    - c\n- d", [bullets([para("a"), bullets([para("b"), bullets([para("c")])])], [para("d")])]],
    ["- a\n\n- b\n\n\n  c\n- d", [bullets([para("a")], [para("b"), para("c")], [para("d")])]],
    ["10. a\n    1. b", [numbers(10, [para("a"), numbers(1, [para("b")])])]],
    ["- a\nlazy\n- b", [bullets([para("a lazy")], [para("b")])]],
    ["- ```\n  code\n  ```", [bullets([code_block("code")])]],
    ["-     indented", [bullets([code_block("indented")])]],
    ["- a\n- - -\n+ b\n\n  c", [bullets([para("a")]), rule, bullets([para("b"), para("c")])]],
    ["1.a\n-b", [para("1.a -b")]]
  ]

  parses "tables", [
    ["| a | b | c |\n|:--|:-:|--:|\n| 1 | *2* | 3 \\| 4 |\n| x |\n\nafter",
     [table(
       [cell(para("a"), header: true, align: :left), cell(para("b"), header: true, align: :center),
        cell(para("c"), header: true, align: :right)],
       [cell(para("1"), align: :left), cell(para(em("2")), align: :center),
        cell(para("3 | 4"), align: :right)],
       [cell(para("x"), align: :left), cell(align: :center), cell(align: :right)]
     ), para("after")]],
    ["a | b\n--- | ---\nc | d | e\n# h", [table([cell(para("a"), header: true), cell(para("b"), header: true)],
                                                [cell(para("c")), cell(para("d"))]), heading(1, "h")]],
    ["| a |\n| --- | --- |", [para("| a | | --- | --- |")]]
  ]

  parses "references", [
    ["[foo]: /url \"title\"\n[Bar  Baz]: <my url>\n\n[foo] and [x][foo] and [FOO][] and [bar baz]",
     [para(txt("foo", link: "/url"), " and ", txt("x", link: "/url"), " and ", txt("FOO", link: "/url"),
           " and ", txt("bar baz", link: "my url"))]],
    ["[a]\n\n[a]: /first\n[a]: /second", [para(txt("a", link: "/first"))]],
    ["> [q]: /quoted\n\n[q]", [quote, para(txt("q", link: "/quoted"))]]
  ]

  parses "images", [
    ["![alt *x*](a.png \"t\") after", [image("a.png", "alt x"), para("after")]],
    ["# A ![i](i.png) title", [heading(1, "A i title")]]
  ]

  it "starts a list item with at most one blank line" do
    expect(parse("-\n  foo\n-\n\n  bar\n- c")).to eq([bullets([para("foo")], []), para("bar"), bullets([para("c")])])
  end

  it "normalises line endings and tabs" do
    expect(parse("\tcode\r\n\r\n-\ta\r")).to eq([code_block("code"), bullets([para("a")])])
  end

  it "never raises on malformed input" do
    ["*_~`[](<>!&\\", "[a](", "> > >", "1.\n\n  2)", "| |\n|-|", "```", "* **\n***", "[x]:"]
      .each { |source| expect { parse(source) }.not_to raise_error }
  end
end
