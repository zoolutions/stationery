# frozen_string_literal: true

require "stationery/markdown/inline_parser"

RSpec.describe Stationery::Markdown::InlineParser do
  def parse(text, refs = {}) = described_class.parse(text, refs)

  def self.link(href, extra = {}) = { link: href, **extra }

  def self.rows # rubocop:disable Metrics/MethodLength
    b = { bold: true }
    i = { italic: true }
    bi = { bold: true, italic: true }
    {
      "emphasis" => [
        ["*foo bar*", [["foo bar", i]]],
        ["_foo bar_", [["foo bar", i]]],
        ["a * foo bar*", [["a * foo bar*"]]],
        ["**foo** bar", [["foo", b], [" bar"]]],
        ["__foo__bar", [["__foo__bar"]]],
        ["_foo_bar_", [["foo_bar", i]]],
        ["foo_bar_", [["foo_bar_"]]],
        ["*foo*bar", [["foo", i], ["bar"]]],
        ["_(bar)_.", [["(bar)", i], ["."]]],
        ["\\*not emphasis\\*", [["*not emphasis*"]]],
        ["***both***", [["both", bi]]],
        ["*foo **bar** baz*", [["foo ", i], ["bar", bi], [" baz", i]]],
        ["**foo*", [["*"], ["foo", i]]],
        ["*foo**", [["foo", i], ["*"]]],
        ["*foo _bar* baz_", [["foo _bar", i], [" baz_"]]],
        ["~~gone~~ and ~one~", [["gone", { strike: true }], [" and "], ["one", { strike: true }]]],
        ["~~a~ ~", [["~~a~ ~"]]]
      ],
      "code spans" => [
        ["`code`", [["code", { code: true }]]],
        ["`` a ` b ``", [["a ` b", { code: true }]]],
        ["` `` `", [["``", { code: true }]]],
        ["`  `", [["  ", { code: true }]]],
        ["`a\nb`", [["a b", { code: true }]]],
        ["`\\*`", [["\\*", { code: true }]]],
        ["*`x*`", [["*"], ["x*", { code: true }]]],
        ["`unclosed and ``", [["`unclosed and ``"]]]
      ],
      "links" => [
        ["[link](/uri \"title\")", [["link", link("/uri")]]],
        ["[a](<b c>) [d]( /u 'title' ) [e](/u(x)) [f](\\(x\\)) [g]()",
         [["a", link("b c")], [" "], ["d", link("/u")], [" "], ["e", link("/u(x)")], [" "], ["f", link("(x)")],
          [" "], ["g", link("")]]],
        ["[a](/u?x=1&amp;y=2 (paren title))", [["a", link("/u?x=1&y=2")]]],
        ["[not a link] [a] (b) [c](d", [["[not a link] [a] (b) [c](d"]]],
        ["[*emph* link](/u)", [["emph", link("/u", i)], [" link", link("/u")]]],
        ["*[a*](/u)", [["*"], ["a*", link("/u")]]],
        ["[a [b](/x)](/y)", [["[a "], ["b", link("/x")], ["](/y)"]]],
        ["![a [b](/x)](/y)", [:image, "/y", "a b"]],
        ["[x][missing] ]", [["[x][missing] ]"]]],
        ["<https://x.test/a?b> <me@x.test> <mailto:a@b.c> <not a link>",
         [["https://x.test/a?b", link("https://x.test/a?b")], [" "], ["me@x.test", link("mailto:me@x.test")],
          [" "], ["mailto:a@b.c", link("mailto:a@b.c")], [" <not a link>"]]]
      ],
      "breaks and entities" => [
        ["a  \nb", [["a"], :br, ["b"]]],
        ["a\\\nb", [["a"], :br, ["b"]]],
        ["a\nb", [["a b"]]],
        ["a \n   b", [["a b"]]],
        ["&amp; &copy &#35; &#x41; \\& \\a !", [["& &copy # A & \\a !"]]]
      ]
    }
  end

  rows.each do |group, examples|
    describe group do
      examples.each do |source, expected|
        it "parses #{source.inspect}" do
          expected = if expected.first == :image
                       [image(expected[1], expected[2])]
                     else
                       expected.map { |item| item == :br ? br : txt(item[0], **(item[1] || {})) }
                     end

          expect(parse(source)).to eq(expected)
        end
      end
    end
  end

  it "resolves references, collapsed and shortcut links" do
    refs = { "foo" => "/url", "bar baz" => "/b" }

    expect(parse("[x][Foo] [foo][] [Bar\n Baz] [nope][]", refs)).to eq(
      [txt("x", link: "/url"), txt(" "), txt("foo", link: "/url"), txt(" "), txt("Bar Baz", link: "/b"),
       txt(" [nope][]")]
    )
  end

  it "reads images with nested alt text" do
    expect(parse("![alt *em*](/img.png \"t\") x")).to eq([image("/img.png", "alt em"), txt(" x")])
  end

  it "normalises reference labels and unescapes destinations" do
    expect(described_class.label("  Foo \n Bar ")).to eq("foo bar")
    expect(described_class.destination("\\(a\\)&amp;")).to eq("(a)&")
  end
end
