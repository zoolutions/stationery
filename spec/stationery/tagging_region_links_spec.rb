# frozen_string_literal: true

RSpec.describe "Tagged PDF links of headers, footers and page templates" do # rubocop:disable RSpec/DescribeClass
  let(:tagged) do
    Class.new(SpecDocument) do
      tagged
      metadata title: "Report", lang: "en"
    end
  end
  let(:linked) do
    Class.new(tagged) do
      header { text "Home", link: "https://example.com/head" }
      footer { text %(See <link href="https://example.com">example.com</link> for more), markup: true }
      page_template { |page| box(at: [36, page.height - 20], link: "https://example.com/stamp") { text "Stamp" } }
    end
  end

  def build(klass = tagged, &) = Class.new(klass) { define_method(:view_template, &) }.new

  def two_pages
    build(linked) do
      text "Report", heading: 1
      text "First"
      page_break
      text "Second"
    end
  end

  it "tags each link as a Link after the content of its page, in the order the regions are painted" do
    doc = two_pages
    pdf = doc.to_pdf

    expect(doc.warnings).to be_empty
    expect(pdf).to have_structure(
      [[:Document, [[:H1, "Report"], [:P, "First"],
                    [:Link, "Home"], [:Link, "example.com"], [:Link, [[:P, "Stamp"]]],
                    [:P, "Second"],
                    [:Link, "Home"], [:Link, "example.com"], [:Link, [[:P, "Stamp"]]]]]]
    )
  end

  it "gives every annotation the /StructParent of its Link" do
    pdf = two_pages.to_pdf

    expect(unpacked(pdf).scan("/StructParent ").size).to eq(6)
    expect(parent_tree(pdf).values.grep(Symbol)).to eq(%i[Link] * 6)
    expect(inspect_pdf(pdf).links).to eq(%w[https://example.com/head https://example.com
                                            https://example.com/stamp] * 2)
  end

  it "keeps the rest of the region a pagination artifact, closed around the link" do
    content = page_contents(two_pages.to_pdf).first

    expect(content).to include("/Artifact <</Type /Pagination /Subtype /Footer>> BDC")
    expect(inspect_pdf(two_pages.to_pdf).untagged_text).to be_empty
    expect(content.scan(/BDC|BMC/).size).to eq(content.scan("EMC").size)
    expect(content).not_to match(%r{/Artifact[^\n]*\n(?:(?!EMC\n).)*/Link <<}m)
    expect(text_of(two_pages.to_pdf)).to include("See example.com for more")
  end

  it "marks a link of several words and lines once" do
    klass = Class.new(tagged) do
      footer { box(width: 60) { text "Read all of the terms here", link: "https://example.com" } }
    end
    pdf = build(klass) { text "Body" }.to_pdf

    expect(pdf).to have_structure([[:Document, [[:P, "Body"], [:Link, "Read all of the terms here"]]]])
    expect(page_contents(pdf).first.scan("/Link <<").size).to eq(1)
  end

  it "resolves a link to an anchor" do
    klass = Class.new(tagged) { footer { text "Top", link: "#top" } }
    doc = build(klass) do
      anchor "top"
      text "Report", heading: 1
    end
    pdf = doc.to_pdf

    expect(doc.warnings).to be_empty
    expect(pdf).to have_structure([[:Document, [[:H1, "Report"], [:Link, "Top"]]]])
    expect(inspect_pdf(pdf).internal_links.size).to eq(1)
  end

  it "places the link of a page without content after the links of the page before" do
    klass = Class.new(tagged) { footer { |page| text "Foot #{page.number}", link: "https://example.com" } }
    doc = build(klass) do
      box(height: 10, background: "#000000")
      page_break
      text "Second"
      page_break
      box(height: 10, background: "#000000")
      page_break
      text "Fourth"
    end

    expect(doc.to_pdf).to have_structure(
      [[:Document, [[:Link, "Foot 1"], [:P, "Second"], [:Link, "Foot 2"], [:Link, "Foot 3"], [:P, "Fourth"],
                    [:Link, "Foot 4"]]]]
    )
  end

  it "places the link after an element that continues on the next page" do
    klass = Class.new(tagged) { footer { |page| text "Foot #{page.number}", link: "https://example.com" } }
    doc = build(klass) do
      text "Report", heading: 1
      table(Array.new(12) { ["Row #{it}"] })
      page_break
      text "End"
    end
    pdf = doc.to_pdf
    structure = inspect_pdf(pdf).structure.first.last

    expect(page_count(pdf)).to eq(4)
    expect(structure.map(&:first)).to eq(%i[H1 Table Link Link Link P Link])
    expect(structure.select { it.first == :Link }.map(&:last)).to eq(["Foot 1", "Foot 2", "Foot 3", "Foot 4"])
  end

  it "is the same structure in an incremental render and a streamed one" do
    doc = two_pages
    pdf = doc.to_pdf
    file = String.new(encoding: Encoding::BINARY)
    two_pages.to_pdf(incremental: true) { |chunk| file << chunk }

    expect(inspect_pdf(file).structure).to eq(inspect_pdf(pdf).structure)
    expect(parent_tree(file).values.grep(Symbol)).to eq(%i[Link] * 6)
    expect(inspect_pdf(file).untagged_text).to be_empty
  end

  it "claims PDF/UA-1, alone and with PDF/A-3b" do
    doc = two_pages

    expect(doc.to_pdf(conformance: :pdf_ua1)).to have_structure(inspect_pdf(two_pages.to_pdf).structure)
    both = unpacked(doc.to_pdf(conformance: %i[pdf_ua1 pdf_a3b]))
    expect(both.scan(%r{/Contents \(https://example.com}).size).to eq(6)
  end

  it "leaves the regions of a tagged document without a link as they were" do
    klass = Class.new(tagged) do
      header { text "Running head", heading: 1 }
      footer { text "Page <page/> of <pages/>", markup: true }
    end
    pdf = build(klass) { text "Body" }.to_pdf

    expect(pdf).to have_structure([[:Document, [[:P, "Body"]]]])
    expect(page_contents(pdf).first.scan("/Artifact <<").size).to eq(2)
  end

  it "leaves a document that is not tagged alone" do
    klass = Class.new(SpecDocument) { footer { text "example.com", link: "https://example.com" } }
    pdf = build(klass) { text "Body" }.to_pdf

    expect(page_contents(pdf).join).not_to include("BDC", "BMC")
    expect(catalog_of(pdf).keys).not_to include(:StructTreeRoot, :MarkInfo)
    expect(inspect_pdf(pdf).links).to eq(["https://example.com"])
  end
end
