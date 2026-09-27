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

  it "keys annotations after the pages and writes an OBJR for each one written" do
    link = element(:Link)
    tree.mark(pages[0], link)
    annotation = { rect: [0, 0, 1, 1], url: "https://example.com", tag: link }
    link.kids << Stationery::Tagging::ObjectRef.new(pages[0], annotation)
    link.kids << Stationery::Tagging::ObjectRef.new(pages[0], { rect: [0, 0, 1, 1] })
    cell = element(:TD, attributes: { Table: { ColSpan: 2 }, Layout: { Width: 3 } })
    tree.mark(pages[0], cell)

    expect(structure.annotation({ rect: [0, 0, 1, 1] }, pdf_writer.reserve)).to eq({})
    annot = pdf_writer.reserve
    expect(structure.annotation(annotation, annot)).to eq(StructParent: 1)
    root = object(structure.write(pdf_writer)[:StructTreeRoot])
    link_ref, cell_ref = object(root[:K].first)[:K]
    expect(object(link_ref)[:K]).to eq([0, { Type: :OBJR, Obj: annot, Pg: refs[0] }])
    expect(object(cell_ref)[:A]).to eq([{ O: :Table, ColSpan: 2 }, { O: :Layout, Width: 3 }])
    expect(root[:ParentTree]).to eq(Nums: [0, [link_ref, cell_ref], 1, link_ref])
    expect(root[:ParentTreeNextKey]).to eq(2)
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
