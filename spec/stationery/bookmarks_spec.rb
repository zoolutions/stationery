# frozen_string_literal: true

RSpec.describe "Bookmarks and the document outline" do # rubocop:disable RSpec/DescribeClass
  def summary(pdf) = outline_of(pdf).map { |node| [node[:title], node[:page], node[:children].size] }

  it "turns bookmarked headings on pages 1-3 into an outline pointing at their pages" do
    pdf = SpecDocument.build do
      text "Introduction", size: 18, bookmark: "Introduction"
      page_break
      box(bookmark: { title: "Scope", level: 2, open: true }) { text "Scope" }
      group(bookmark: "Details", anchor: "details") { text "Details" }
      page_break
      bookmark "Appendix", level: 1
      table([%w[a b]], bookmark: { title: "Rows", level: 2 })
      text "back", link: "#details"
    end.to_pdf

    expect(summary(pdf)).to eq([["Introduction", 0, 1], ["Details", 1, 0], ["Appendix", 2, 1]])
    expect(outline_of(pdf)[0][:children].map { |node| [node[:title], node[:page]] }).to eq([["Scope", 1]])
    expect(outline_of(pdf)[0][:top]).to eq(180)
    expect(link_destinations(pdf).map { |from, to, _| [from, to] }).to eq([[2, 1]])
    expect(pdf).to include("/PageMode /UseOutlines")
  end

  it "writes no outline without bookmarks" do
    pdf = SpecDocument.build { text "plain" }.to_pdf

    expect(outline_of(pdf)).to be_nil
    expect(pdf).not_to include("/PageMode")
  end

  it "ignores bookmarks in page templates" do
    klass = Class.new(SpecDocument) do
      page_template { box(at: [20, 5]) { text "header", bookmark: "Header" } }
      def view_template = text("body", bookmark: "Body")
    end
    doc = klass.new
    pdf = doc.to_pdf

    expect(summary(pdf)).to eq([["Body", 0, 0]])
    expect(doc.warnings).to be_empty
  end

  it "never lets a page template's bookmark stand in for an unpainted body bookmark" do
    klass = Class.new(SpecDocument) do
      page_template { box(at: [20, 5]) { text "header", bookmark: "Header" } }
      def view_template
        box(height: 20, overflow: :hidden) do
          spacer 30
          text "clipped", bookmark: "Lost"
        end
      end
    end

    expect(outline_of(klass.new.to_pdf)).to be_nil
  end

  it "skips a bookmark whose content never paints" do
    pdf = SpecDocument.build do
      box(height: 20, overflow: :hidden) do
        spacer 30
        text "clipped", bookmark: "Lost"
      end
      text "kept", bookmark: "Kept"
    end.to_pdf

    expect(summary(pdf)).to eq([["Kept", 0, 0]])
  end
end
