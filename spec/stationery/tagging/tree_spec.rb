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
                                             "image on page 2 has no alt: text (alt: false marks decoration)"])
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

  describe "#audit of heading levels" do
    let(:warnings) { Stationery::Warnings.new }

    def heading(level, parent: tree.root, page: pages[0])
      Stationery::Tagging::Element.new(:"H#{level}").tap do |element|
        element.attach(parent)
        tree.mark(page, element) if page
      end
    end

    def skipped(level, allowed, page) = Stationery::Warnings::SkippedHeading.new(level:, allowed:, page:)

    def audit
      tree.audit(pages, warnings, lang: "en")
      warnings.to_a
    end

    it "is quiet when levels go down one at a time and come back up by any amount" do
      [1, 2, 3, 4, 5, 6, 1, 2, 2, 3, 1, 1].each { |level| heading(level) }

      expect(audit).to be_empty
    end

    it "wants the first heading to be H1" do
      heading(2, page: pages[1])
      heading(3)

      expect(audit).to eq([skipped(2, 1, 2)])
      expect(warnings.map(&:message)).to eq(["heading 2 on page 2 skips a level: the first heading is heading 1"])
    end

    it "warns per heading that skips a level and measures the next against it" do
      [1, 3, 4, 6].each_with_index { |level, index| heading(level, page: pages[index % 2]) }

      expect(audit).to eq([skipped(3, 2, 2), skipped(6, 5, 2)])
      expect(warnings.map(&:message))
        .to eq(["heading 3 on page 2 skips a level: heading 2 is the deepest that may follow heading 1",
                "heading 6 on page 2 skips a level: heading 5 is the deepest that may follow heading 4"])
    end

    it "reads the headings in the order of the tree, not of the pages" do
      heading(1)
      section = Stationery::Tagging::Element.new(:Sect).tap { it.attach(tree.root) }
      heading(3, page: pages[0])
      heading(2, parent: section, page: pages[1])

      expect(tree.root.elements.map(&:type)).to eq(%i[H1 Sect H3])
      expect(audit).to be_empty
    end

    it "finds the headings nested in other elements" do
      heading(1)
      cell = %i[Table TR TD].inject(tree.root) do |parent, type|
        Stationery::Tagging::Element.new(type).tap { it.attach(parent) }
      end
      heading(3, parent: cell, page: pages[1])

      expect(audit).to eq([skipped(3, 2, 2)])
    end

    it "passes over a heading that holds no content, which is not written" do
      heading(1)
      heading(2, page: nil)
      heading(3)

      expect(audit).to eq([skipped(3, 2, 1)])
    end

    it "takes the page of a heading from the content of its links" do
      title = heading(2, page: nil)
      Stationery::Tagging::Element.new(:Link).attach(title)
      link = Stationery::Tagging::Element.new(:Link).tap { it.attach(title) }
      tree.mark(pages[1], link)

      expect(audit).to eq([skipped(2, 1, 2)])
    end
  end
end
