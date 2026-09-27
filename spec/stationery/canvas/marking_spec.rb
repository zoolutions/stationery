# frozen_string_literal: true

RSpec.describe Stationery::Canvas::Marking do
  let(:page) { Stationery::Page.new(size: [100, 100]) }
  let(:tree) { Stationery::Tagging::Tree.new }
  let(:paragraph) { Stationery::Tagging::Element.new(:P) }

  def canvas(tagging = tree) = Stationery::Canvas.new(page, nil, tagging:)

  it "only yields without a tagging tree" do
    untagged = canvas(nil)
    untagged.structure(Stationery::Tagging::Element.new(:Sect)) do
      untagged.tag(paragraph) { untagged.fill_rect(0, 0, 1, 1, color: "#000000") }
    end
    untagged.artifact(type: :pagination) { untagged.fill_rect(0, 0, 1, 1, color: "#000000") }

    expect(page.content).not_to include("BDC", "BMC", "EMC")
    expect(untagged).not_to be_tagging
    expect(paragraph.parent).to be_nil
  end

  it "nests elements opened with structure and marks content once" do
    section = Stationery::Tagging::Element.new(:Sect)
    tagged = canvas
    tagged.structure(section) do
      tagged.tag(paragraph) { tagged.fill_rect(0, 0, 1, 1, color: "#000000") }
    end

    expect(tagged).to be_tagging
    expect(tree.root.kids).to eq([section])
    expect(section.kids).to eq([paragraph])
    expect(page.content).to eq("/P <</MCID 0>> BDC\nq\n0 0 0 rg\n0 99 1 1 re\nf\nQ\nEMC\n")
  end

  it "keeps elements painted inside an artifact out of the tree" do
    tagged = canvas
    tagged.artifact(type: :pagination, subtype: :header) do
      tagged.structure(Stationery::Tagging::Element.new(:Sect)) { tagged.tag(paragraph) { nil } }
      tagged.artifact { nil }
    end

    expect(page.content).to eq("/Artifact <</Type /Pagination /Subtype /Header>> BDC\nEMC\n")
    expect(tree.root.kids).to be_empty
  end

  it "records a figure's bounding box in PDF space" do
    figure = Stationery::Tagging::Element.new(:Figure)
    canvas.tag(figure, bbox: [10, 20, 30, 40]) { nil }

    expect(figure.bbox).to eq([10, 40, 40, 80])
  end
end
