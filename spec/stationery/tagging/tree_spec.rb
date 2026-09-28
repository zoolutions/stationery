# frozen_string_literal: true

RSpec.describe Stationery::Tagging::Tree do
  subject(:tree) { described_class.new }

  let(:pages) { Array.new(2) { Stationery::Page.new(size: [100, 100]) } }
  let(:paragraph) { Stationery::Tagging::Element.new(:P) }

  it "numbers marked content per page in paint order and remembers the element of each" do
    heading = Stationery::Tagging::Element.new(:H1)

    expect(tree.mark(pages[0], heading)).to eq(0)
    expect(tree.mark(pages[0], paragraph)).to eq(1)
    expect(tree.mark(pages[1], paragraph)).to eq(0)
    expect(tree.marked(pages[0])).to eq([heading, paragraph])
    expect(tree.marked(Stationery::Page.new)).to eq([])
    expect(paragraph.kids).to eq([Stationery::Tagging::MarkedContent.new(pages[0], 1),
                                  Stationery::Tagging::MarkedContent.new(pages[1], 0)])
  end

  it "attaches an element to its parent once, on first use" do
    section = Stationery::Tagging::Element.new(:Sect)
    section.attach(tree.root)
    paragraph.attach(section)
    paragraph.attach(tree.root)

    expect(tree.root.kids).to eq([section])
    expect(section.kids).to eq([paragraph])
    expect(paragraph.parent).to be(section)
  end

  it "records the first bounding box only" do
    figure = Stationery::Tagging::Element.new(:Figure, alt: "Logo")
    figure.place([0, 0, 10, 10])
    figure.place([5, 5, 10, 10])

    expect(figure.bbox).to eq([0, 0, 10, 10])
    expect(figure.alt).to eq("Logo")
  end

  describe "#audit" do
    let(:warnings) { Stationery::Warnings.new }

    it "warns once about a missing language and per figure without alt text" do
      image = Stationery::Tagging::Element.new(:Figure, kind: :image)
      image.attach(tree.root)
      tree.mark(pages[1], image)
      described = Stationery::Tagging::Element.new(:Figure, alt: "Chart", kind: :svg)
      described.attach(tree.root)
      tree.mark(pages[0], described)
      tree.audit(pages, warnings, lang: nil)

      expect(warnings.to_a).to eq([Stationery::Warnings::MissingLanguage.new,
                                   Stationery::Warnings::MissingAlt.new(kind: :image, page: 2)])
      expect(warnings.map(&:message)).to eq(["tagged PDF has no language: set metadata lang:",
                                             "image on page 2 has no alt: text"])
    end

    it "is quiet with a language and described figures" do
      tree.audit(pages, warnings, lang: "en")

      expect(warnings).to be_empty
    end

    it "warns about a figure whose alt text is blank" do
      { image: "", svg: " \n\t", chart: "\u00A0", photo: "Chart" }.each_with_index do |(kind, alt), index|
        figure = Stationery::Tagging::Element.new(:Figure, alt:, kind:)
        figure.attach(tree.root)
        tree.mark(pages[index % 2], figure)
      end
      tree.audit(pages, warnings, lang: "en")

      expect(warnings.to_a).to eq([Stationery::Warnings::MissingAlt.new(kind: :image, page: 1),
                                   Stationery::Warnings::MissingAlt.new(kind: :svg, page: 2),
                                   Stationery::Warnings::MissingAlt.new(kind: :chart, page: 1)])
    end
  end
end
