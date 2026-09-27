# frozen_string_literal: true

RSpec.describe "Anchors and internal links" do # rubocop:disable RSpec/DescribeClass
  def render(&)
    doc = SpecDocument.build(&)
    [doc.to_pdf, doc]
  end

  it "links text to an anchored paragraph that moved to the next page" do
    pdf, doc = render do
      text "go", link: "#intro"
      spacer 140
      text "Intro", anchor: "intro"
    end

    expect(page_count(pdf)).to eq(2)
    expect(link_destinations(pdf)).to eq([[0, 1, 180]])
    expect(doc.warnings).to be_empty
  end

  it "links from markup and from boxes, to boxes, groups and tables" do
    pdf, = render do
      text %(<a href="#totals">totals</a>), markup: true
      box(link: "#rows") { text "rows" }
      group(anchor: "group") { text "grouped" }
      page_break
      box(anchor: "totals") { text "Totals" }
      table([%w[a b]], anchor: "rows")
      text "back", link: "#group"
    end

    expect(link_destinations(pdf).map { |from, to, _| [from, to] }).to eq([[0, 1], [0, 1], [1, 0]])
  end

  it "moves a standalone anchor with the heading that follows it" do
    pdf, = render do
      text "go", link: "#appendix"
      spacer 135
      anchor "appendix"
      text "Appendix", size: 20
    end

    expect(link_destinations(pdf)).to eq([[0, 1, 180]])
  end

  it "drops a link to an unknown anchor and warns" do
    pdf, doc = render { text "nowhere", link: "#missing" }

    expect(pdf).not_to include("/Annots")
    expect(doc.warnings.to_a).to eq([Stationery::Warnings::UnresolvedLink.new(name: "missing", page: 1)])
  end

  it "raises in strict mode on a duplicate anchor" do
    doc = SpecDocument.build do
      anchor "x"
      text "one", anchor: "x"
    end

    expect { doc.to_pdf(strict: true) }.to raise_error(Stationery::WarningsError, /anchor "x" on page 1/)
  end

  it "resolves an anchor drawn by a page template without a duplicate warning" do
    klass = Class.new(SpecDocument) do
      page_template { box(at: [20, 5], anchor: "top") { text "header" } }
      def view_template
        text "back to top", link: "#top"
        page_break
        text "second"
      end
    end
    doc = klass.new
    pdf = doc.to_pdf

    expect(link_destinations(pdf)).to eq([[0, 0, 195]])
    expect(doc.warnings).to be_empty
  end
end
