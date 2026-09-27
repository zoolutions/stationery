# frozen_string_literal: true

RSpec.describe Stationery::Tagging::Writer do
  let(:tree) { Stationery::Tagging::Tree.new }
  let(:pages) { Array.new(3) { Stationery::Page.new(size: [100, 100]) } }
  let(:pdf_writer) { Stationery::PDF::Writer.new }
  let(:refs) { pages.map { pdf_writer.reserve } }
  let(:structure) { described_class.new(tree, pages:, refs:) }

  def element(type, parent = tree.root, **)
    Stationery::Tagging::Element.new(type, **).tap { |el| el.attach(parent) }
  end

  def object(ref) = pdf_writer.instance_variable_get(:@objects)[ref.id - 1]

  it "keys only the pages that hold marked content" do
    tree.mark(pages[2], element(:P))

    expect(structure.page_entries(pages[0])).to eq({})
    expect(structure.page_entries(pages[2])).to eq(StructParents: 0)
  end

  it "writes the tree, a parent tree and the catalog entries, leaving out empty elements" do
    paragraph = element(:P)
    tree.mark(pages[0], paragraph)
    tree.mark(pages[1], paragraph)
    figure = element(:Figure, alt: "Logo")
    figure.place([1, 2, 3, 4])
    tree.mark(pages[1], figure)
    element(:Sect)
    catalog = structure.write(pdf_writer)

    expect(catalog).to include(MarkInfo: { Marked: true })
    root = object(catalog[:StructTreeRoot])
    expect(root).to include(Type: :StructTreeRoot, ParentTreeNextKey: 2)
    document = object(root[:K].first)
    expect(document).to include(S: :Document, P: catalog[:StructTreeRoot])
    expect(document[:K].size).to eq(2)
    expect(object(document[:K][0])).to include(S: :P, Pg: refs[0], K: [0, { Type: :MCR, Pg: refs[1], MCID: 0 }])
    fig = object(document[:K][1])
    expect(fig).to include(S: :Figure, Pg: refs[1], K: [1], A: { O: :Layout, BBox: [1, 2, 3, 4] })
    expect(fig[:Alt]).to eq(Stationery::PDF::TextString.new("Logo"))
    expect(root[:ParentTree]).to eq(Nums: [0, [document[:K][0]], 1, document[:K]])
  end
end
