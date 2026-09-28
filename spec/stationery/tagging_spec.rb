# frozen_string_literal: true

RSpec.describe "Tagged PDF" do # rubocop:disable RSpec/DescribeClass
  let(:tagged) do
    Class.new(SpecDocument) do
      tagged
      metadata title: "Report", lang: "en-US"
      footer { text "Page footer" }
    end
  end

  def build(klass = tagged, &) = Class.new(klass) { define_method(:view_template, &) }.new

  it "marks the catalog and wraps the first paragraph in marked content" do
    pdf = build { text "Hello" }.to_pdf
    catalog = catalog_of(pdf)

    expect(catalog[:MarkInfo]).to eq(Marked: true)
    expect(catalog[:Lang]).to eq("en-US")
    expect(catalog[:ViewerPreferences]).to eq(DisplayDocTitle: true)
    expect(catalog).to have_key(:StructTreeRoot)
    expect(page_contents(pdf).first).to match(%r{\A/P <</MCID 0>> BDC\nq\n.*?BT.*?ET\nQ\nEMC\n}m)
    expect(reader_for(pdf).info).not_to have_key(:lang)
  end

  it "paints a box shadow as an artifact" do
    content = page_contents(build { box(shadow: true, background: "#FFFFFF") { text "Card" } }.to_pdf).first

    expect(content).to match(%r{\A/Artifact BMC\nq\n/GS1 gs\n.*?EMC\n}m)
    expect(content.scan(%r{/GS\d+ gs}).size).to eq(4)
    expect(struct_types(build { box(shadow: true) { text "Card" } }.to_pdf)).to eq([[:Document, [:P]]])
  end

  it "attaches a stack's base and layers in paint order" do
    logo = image_path("rgb.jpg")
    pdf = build do
      stack do
        image logo, width: 100, height: 60, fit: :cover, alt: "Base"
        layer(top: 0, left: 0, padding: 2, background: "#FFFFFF") { text "Over" }
      end
    end.to_pdf

    expect(struct_types(pdf)).to eq([[:Document, %i[Figure P]]])
  end

  it "paints the footer as a pagination artifact" do
    content = page_contents(build { text "Body" }.to_pdf).first

    expect(content).to match(%r{/Artifact <</Type /Pagination /Subtype /Footer>> BDC\n.*EMC}m)
    expect(content.scan(/BDC|BMC/).size).to eq(content.scan("EMC").size)
  end

  it "builds Document → H1, P and Figure with its alt text" do
    logo = image_path("rgb.jpg")
    pdf = build do
      text "Intro", heading: 1
      text "Body"
      image logo, width: 20, alt: "Company logo"
    end.to_pdf

    expect(struct_types(pdf)).to eq([[:Document, %i[H1 P Figure]]])
    figure = struct_tree(pdf)[0][2][2]
    expect(figure[1]).to eq("Company logo")
    expect(figure[2]).to eq([[0, 2]])
    expect(parent_tree(pdf)).to eq(0 => %i[H1 P Figure])
  end

  it "keeps a paragraph split across pages as one P with marked content on both" do
    pdf = build { text Array.new(20) { |i| "line #{i}" }.join("\n") }.to_pdf

    expect(page_count(pdf)).to eq(2)
    expect(struct_tree(pdf)).to eq([[:Document, nil, [[:P, nil, [[0, 0], [1, 0]]]]]])
    expect(parent_tree(pdf)).to eq(0 => [:P], 1 => [:P])
    expect(reader_for(pdf).pages.map { |page| page.attributes[:StructParents] }).to eq([0, 1])
  end

  it "maps box roles to grouping elements and keeps plain boxes transparent" do
    pdf = build do
      box(role: :section) do
        text "Inside"
        box(padding: 2, background: "#EEEEEE") { text "Plain" }
      end
      box(role: :blockquote) { text "Quoted" }
    end.to_pdf

    expect(struct_types(pdf)).to eq([[:Document, [[:Sect, %i[P P]], [:BlockQuote, [:P]]]]])
  end

  it "rejects an unknown role and heading level" do
    expect { build { box(role: :banner) { text "x" } }.to_pdf }.to raise_error(ArgumentError, /role/)
    expect { build { text "x", heading: 7 }.to_pdf }.to raise_error(ArgumentError, /heading/)
  end

  it "marks decoration drawn outside any element as an artifact" do
    content = page_contents(build { rule(height: 2) }.to_pdf).first

    expect(content).to start_with("/Artifact BMC\nq\n")
  end

  it "paints a decorative image as an artifact without a warning" do
    logo = image_path("rgb.jpg")
    doc = build { image logo, width: 20, alt: false }
    pdf = doc.to_pdf

    expect(struct_tree(pdf)).to eq([[:Document, nil, []]])
    expect(page_contents(pdf).first).to start_with("/Artifact BMC\nq\n")
    expect(doc.warnings.to_a).to be_empty
  end

  it "warns about figures without alt text and a missing language" do
    klass = Class.new(SpecDocument) { tagged }
    logo = image_path("rgb.jpg")
    doc = build(klass) do
      image logo, width: 20
      svg %(<svg viewBox="0 0 10 10"><rect width="10" height="10"/></svg>), width: 10
    end
    doc.to_pdf

    expect(doc.warnings.map(&:message)).to eq(["tagged PDF has no language: set metadata lang:",
                                               "image on page 1 has no alt: text (alt: false marks decoration)",
                                               "svg on page 1 has no alt: text (alt: false marks decoration)"])
    expect { doc.to_pdf(strict: true) }.to raise_error(Stationery::WarningsError)
  end

  it "tags on request and leaves documents untagged by default" do
    doc = SpecDocument.build { text "Hello", heading: 2 }

    plain = doc.to_pdf
    expect(page_contents(plain).first).not_to include("BDC")
    expect(catalog_of(plain).keys).not_to include(:StructTreeRoot, :MarkInfo, :Lang)
    expect(struct_types(doc.to_pdf(tagged: true))).to eq([[:Document, [:H2]]])
  end

  it "takes a rich-text image's alt text" do
    assets = PdfHelpers::IMAGES
    pdf = build { html %(<p>Logo</p><img src="rgb.jpg" alt="The logo" width="10">), base_path: assets }.to_pdf

    expect(struct_tree(pdf)[0][2].map { |type, alt, _| [type, alt] }).to eq([[:P, nil], [:Figure, "The logo"]])
  end

  it "tags form fields as Form elements owning their widgets" do
    pdf = build do
      text "Apply"
      text_field "name", value: "Ann", width: 120
      checkbox "agree", checked: true, label: "I agree"
    end.to_pdf
    objects = reader_for(pdf).objects
    widgets = objects.values.select { |obj| obj.is_a?(Hash) && obj[:Subtype] == :Widget }
    forms = struct_tree(pdf)[0][2].select { |type, _, _| type == :Form }

    expect(struct_types(pdf)).to eq([[:Document, %i[P Form Form P]]])
    expect(widgets.map { |w| w[:StructParent] }).to all(be_an(Integer))
    expect(forms.size).to eq(2)
    elements = objects.values.select { |obj| obj.is_a?(Hash) && obj[:Type] == :StructElem && obj[:S] == :Form }
    objrs = elements.flat_map { |elem| Array(objects.deref(elem[:K])).map { |kid| objects.deref(kid) } }
    expect(objrs.map { |o| [o[:Type], objects.deref(o[:Obj])[:Subtype]] }).to eq([%i[OBJR Widget]] * 2)
  end

  it "keeps page template content out of the structure" do
    logo = image_path("rgb.jpg")
    klass = Class.new(tagged) { page_template { box(at: [5, 5]) { image logo, width: 5 } } }
    doc = build(klass) { text "Body" }
    pdf = doc.to_pdf

    expect(page_contents(pdf).first).to include("/Artifact <</Type /Pagination>> BDC")
    expect(struct_types(pdf)).to eq([[:Document, [:P]]])
    expect(doc.warnings).to be_empty
  end
end
