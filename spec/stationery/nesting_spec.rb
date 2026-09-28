# frozen_string_literal: true

require "stationery/html/document"
require "stationery/markdown/document"

# Content from users can nest as deep as its author likes. Parsing, laying
# out and painting all recurse over that nesting, so past a limit the
# parsers flatten: the text stays, the structure goes, a warning says so,
# and nothing raises (least of all SystemStackError, which nobody rescues).
RSpec.describe "nesting limits" do # rubocop:disable RSpec/DescribeClass
  let(:limit_warning) { Stationery::Warnings::NestingLimit }

  def document(&) = SpecDocument.build(&)

  # `text` inside `times` of `opening`, each closed again.
  def nest(opening, text, closing, times) = "#{opening * times}#{text}#{closing * times}"

  describe "html" do
    def parse(source, **, &) = Stationery::HTML.parse(source, **, &)

    it "flattens what nests deeper than max_depth into the deepest element kept" do
      deepest = nil
      source = "<blockquote>a<blockquote>b<blockquote>c</blockquote> d</blockquote> e</blockquote>"

      blocks = parse(source, max_depth: 2) { |depth| deepest = depth }

      expect(blocks).to eq([quote(para("a"), quote(para("b c d")), para("e"))])
      expect(deepest).to eq(3)
    end

    it "keeps void elements and the text of what it flattens, and closes what it kept where the source does" do
      blocks = parse("<div><section>one<br><img src='a.png'><b>two</b><hr>three</section>four</div>five", max_depth: 1)

      expect(blocks).to eq([para("one"), image("a.png"), para("two"), rule, para("three four"), para("five")])
    end

    it "counts from the elements left open, so closed siblings never add up" do
      deepest = nil
      blocks = parse("<p>a</p><p>b</p><div><p>c</p></div>", max_depth: 2) { |depth| deepest = depth }

      expect(blocks).to eq([para("a"), para("b"), para("c")])
      expect(deepest).to be_nil
    end

    it "bounds tables inside tables the same way" do
      deepest = nil
      nested = nest("<table><tr><td>", "deep", "</td></tr></table>", 40)

      blocks = parse(nested, max_depth: 9) { |depth| deepest = depth }

      depth = 0
      block = blocks.first
      while block.is_a?(Stationery::Rich::Table)
        depth += 1
        block = block.rows.first.first.blocks.first
      end
      expect(depth).to eq(3)
      expect(block).to eq(para("deep"))
      expect(deepest).to eq(120)
    end

    it "refuses a limit that is not a positive Integer" do
      expect { parse("x", max_depth: 0) }.to raise_error(ArgumentError, "max_depth must be a positive Integer (got 0)")
      expect { parse("x", max_depth: nil) }.to raise_error(ArgumentError, /got nil/)
    end

    it "renders 5,000 nested divs: no exception, a warning, the text kept" do
      source = nest("<div>", "deep down", "</div>", 5_000)
      doc = document { html source }

      pdf = doc.to_pdf

      expect(text_of(pdf)).to eq("deep down")
      expect(doc.warnings.to_a).to eq([limit_warning.new(depth: 5_000, limit: 64)])
    end

    it "renders 5,000 nested block quotes, lists and marks within the limit it is given" do
      quotes = nest("<blockquote>", "quoted", "</blockquote>", 5_000)
      lists = nest("<ul><li>", "listed", "</li></ul>", 5_000)
      marks = nest("<b><i>", "marked", "</i></b>", 5_000)
      doc = document do
        html quotes, max_depth: 8
        html lists, max_depth: 8
        html marks
      end

      pdf = doc.to_pdf

      expect(text_of(pdf)).to include("quoted", "listed", "marked")
      expect(doc.warnings.to_a).to contain_exactly(
        limit_warning.new(depth: 5_000, limit: 8), limit_warning.new(depth: 10_000, limit: 8),
        limit_warning.new(depth: 10_000, limit: 64)
      )
    end

    it "says nothing about content within the limit" do
      doc = document { html "<div><blockquote><ul><li><b>fine</b></li></ul></blockquote></div>" }

      doc.to_pdf

      expect(doc.warnings).to be_empty
    end
  end

  describe "markdown" do
    def parse(source, **, &) = Stationery::Markdown.parse(source, **, &)

    it "flattens block quotes nested deeper than max_depth into a paragraph of their own" do
      deepest = nil

      blocks = parse("> a\n> > b\n> > > c\n> > > > d", max_depth: 2) { |depth| deepest = depth }

      expect(blocks).to eq([quote(para("a"), quote(para("b"), para("c d")))])
      expect(deepest).to eq(4)
    end

    it "flattens lists nested deeper than max_depth, markers dropped" do
      deepest = nil

      blocks = parse("- a\n  - b\n    - c\n    - d\n", max_depth: 2) { |depth| deepest = depth }

      expect(blocks).to eq([bullets([para("a"), bullets([para("b"), para("c d")])])])
      expect(deepest).to eq(3)
    end

    it "keeps everything else it finds at the limit" do
      blocks = parse("> # Title\n> text\n>\n>     code\n> > deeper", max_depth: 1)

      expect(blocks).to eq([quote(heading(1, "Title"), para("text"), code_block("code"), para("deeper"))])
    end

    it "refuses a limit that is not a positive Integer" do
      expect { parse("x", max_depth: -1) }
        .to raise_error(ArgumentError, "max_depth must be a positive Integer (got -1)")
    end

    it "renders 5,000 nested block quotes: no exception, a warning, the text kept" do
      source = "#{"> " * 5_000}deep down"
      doc = document { markdown source }

      pdf = doc.to_pdf

      expect(text_of(pdf)).to eq("deep down")
      expect(doc.warnings.to_a)
        .to eq([limit_warning.new(depth: 5_000, limit: 64), limit_warning.new(depth: 64, limit: 12)])
    end

    it "renders a list 600 levels deep" do
      source = (0...600).map { |level| "#{"  " * level}- item #{level}" }.join("\n")
      doc = document { markdown source, max_depth: 4 }

      pdf = doc.to_pdf

      expect(text_of(pdf).split.join(" ")).to include("item 0", "item 599")
      expect(doc.warnings.map(&:limit)).to eq([4])
    end
  end

  describe "markdown inlines" do
    def parse(source) = Stationery::Markdown.parse(source)

    # Generous: each of these took 6 to 17 seconds before it was bounded.
    def within(seconds)
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      yield
      expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).to be < seconds
    end

    it "nests emphasis as deep as it is typed, without recursing" do
      expect(parse("#{"*" * 50_000}deep#{"*" * 50_000}")).to eq([para(txt("deep", bold: true))])
      expect(parse("#{"*" * 7}deep#{"*" * 7}")).to eq([para(txt("deep", italic: true, bold: true))])
    end

    it "keeps at most 64 brackets open, the oldest giving way" do
      images = parse("#{"![" * 66}deep#{"](x)" * 66}")
      links = parse("#{"[" * 66}deep#{"](x)" * 66}")

      expect(images).to eq([para("![!["), image("x", "deep"), para("](x)](x)")])
      expect(links).to eq([para("[" * 65, txt("deep", link: "x"), "](x)" * 65)])
    end

    it "looks a label of 999 characters up, and none longer" do
      defined = ->(label) { "[#{label}]\n\n[#{label}]: /url" }

      expect(parse(defined["a" * 999])).to eq([para(txt("a" * 999, link: "/url"))])
      expect(parse(defined["ü" * 999])).to eq([para(txt("ü" * 999, link: "/url"))])
      expect(parse(defined["a" * 1_000])).to eq([para("[#{"a" * 1_000}]")])
    end

    it "reads the characters around a delimiter run in text of any script" do
      expect(parse("é*a* ü_b_ [ö](x) ~~ß~~ 日本**語**")).to eq(
        [para("é", txt("a", italic: true), " ü_b_ ", txt("ö", link: "x"), " ", txt("ß", strike: true), " 日本",
              txt("語", bold: true))]
      )
    end

    it "takes time in proportion to the input for closers nothing opens and brackets nothing closes" do
      within(5) { expect(parse("a* b_ c~~ " * 7_000).size).to eq(1) }
      within(5) { expect(parse("#{"[" * 20_000}deep#{"]" * 20_000}").size).to eq(1) }
      within(5) { expect(parse("é*a* ü[b] " * 10_000).size).to eq(1) }
    end
  end

  describe "indentation" do
    it "stops indenting block quotes and lists nested deeper than the renderer's limit, keeping the text" do
      quotes = nest("<blockquote>", "quoted", "</blockquote>", 40)
      lists = "#{(0...20).map { |level| "#{"  " * level}- item #{level}" }.join("\n")}\n"
      doc = document do
        html quotes
        markdown lists
      end

      pdf = doc.to_pdf

      expect(text_of(pdf).split.join(" ")).to include("quoted", "item 0", "item 12", "item 19")
      expect(doc.warnings.to_a)
        .to eq([limit_warning.new(depth: 40, limit: 12), limit_warning.new(depth: 20, limit: 12)])
    end

    it "indents twelve levels as it always did" do
      quotes = nest("<blockquote>", "quoted", "</blockquote>", 12)
      doc = document { html quotes }

      doc.to_pdf

      expect(doc.warnings).to be_empty
    end
  end

  describe "svg" do
    def svg(body) = %(<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10">#{body}</svg>)

    it "hoists what nests deeper than the parser's limit into the deepest element kept" do
      deepest = nil
      source = svg("<g id='a'><g id='b'><g id='c'><rect width='1' height='1'/><path d='M0 0'></path></g></g></g>")

      root = Stationery::SVG::Parser.parse(source, max_depth: 3) { |depth| deepest = depth }

      kept = root.children.first.children.first
      expect(kept.attributes).to eq("id" => "b")
      expect(kept.children.map(&:name)).to eq(%w[g rect path])
      expect(kept.children.first.children).to eq([])
      expect(deepest).to eq(5)
    end

    it "leaves a document within the limit alone" do
      deepest = nil
      root = Stationery::SVG::Parser.parse(svg("<g><g><rect/></g></g>")) { |depth| deepest = depth }

      expect(root.children.first.children.first.children.map(&:name)).to eq(["rect"])
      expect(deepest).to be_nil
    end

    it "draws 2,000 nested groups: no exception, a warning, the shape kept" do
      source = svg("#{"<g>" * 2_000}<rect width='5' height='5'/>#{"</g>" * 2_000}")
      doc = document { svg source, width: 50 }

      pdf = doc.to_pdf

      expect(page_contents(pdf).first).to include("20 180 m\n45 180 l\n45 155 l\n20 155 l\nh\nf\n")
      expect(doc.warnings.to_a).to eq([limit_warning.new(depth: 2_001, limit: Stationery::SVG::Parser::MAX_DEPTH)])
    end

    it "stops following a chain of uses, and reports it" do
      links = (0...200).map { |index| %(<use id="u#{index}" href="#u#{index + 1}"/>) }.join
      document = Stationery::SVG::Document.parse(svg("<defs>#{links}<rect id='u200' width='1' height='1'/></defs>" \
                                                     "<use href='#u0'/>"))

      expect(document.unsupported).to eq(["use: nested deeper than #{Stationery::SVG::Walker::MAX_USES}"])
    end
  end

  it "explains itself" do
    expect(limit_warning.new(depth: 5_000, limit: 64).message)
      .to eq("content nested 5000 levels deep was flattened below level 64")
  end
end
