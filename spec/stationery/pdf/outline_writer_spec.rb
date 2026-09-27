# frozen_string_literal: true

RSpec.describe Stationery::PDF::OutlineWriter do
  let(:writer) { Stationery::PDF::Writer.new }
  let(:pages) { Array.new(3) { writer.reserve } }
  let(:rendered) { {} }

  def item(title, level, page = 0, open: false)
    Stationery::Outline::Item.new(title, level, Stationery::Structure::Destination.new(page, 100 + page), open)
  end

  def write(*items)
    root = described_class.new(writer, items, pages).write
    pages.each { |ref| writer.set(ref, { Type: :Page }) }
    catalog = writer.add({ Type: :Catalog, Outlines: root })
    rendered[:objects] = reader_for(writer.render(root: catalog, info: writer.add({}))).objects
    objects.deref(objects.deref(objects.trailer[:Root])[:Outlines])
  end

  def objects = rendered.fetch(:objects)

  def children(node)
    list = []
    ref = node[:First]
    while ref
      list << objects.deref(ref)
      ref = list.last[:Next]
    end
    list
  end

  def titles(node) = children(node).map { |child| child[:Title] }

  it "returns nil without items" do
    expect(described_class.new(writer, [], pages).write).to be_nil
  end

  it "links siblings with Prev/Next and points each at its page and top" do
    root = write(item("A", 1, 0), item("B", 1, 1), item("C", 1, 2))
    a, b, c = children(root)
    root_ref = objects.deref(objects.trailer[:Root])[:Outlines]

    expect(root).to include(Type: :Outlines, Count: 3)
    expect(titles(root)).to eq(%w[A B C])
    expect([a[:Prev], b[:Prev], c[:Next]]).to eq([nil, root[:First], nil])
    expect(objects.deref(root[:Last])).to eq(c)
    expect([a[:Parent], c[:Parent]]).to eq([root_ref, root_ref])
    expect(b[:Dest][0].id).to eq(pages[1].id)
    expect(b[:Dest][1..]).to eq([:XYZ, nil, 101, nil])
    expect(a.keys).not_to include(:Count, :First, :Last)
  end

  it "nests deeper levels, counting closed children negatively and open ones positively" do
    root = write(item("One", 1), item("One.a", 2), item("One.b", 2),
                 item("Two", 1, open: true), item("Two.a", 2, open: true), item("Two.a.i", 3))
    one, two = children(root)
    two_a = children(two).first

    expect(titles(one)).to eq(%w[One.a One.b])
    expect([one[:Count], two[:Count], two_a[:Count]]).to eq([-2, 2, 1])
    expect(titles(two_a)).to eq(%w[Two.a.i])
    expect(objects.deref(two_a[:Parent])).to eq(two)
    expect(root[:Count]).to eq(4)
  end

  it "counts a closed node's hidden descendants at every depth" do
    root = write(item("Top", 1), item("Mid", 2, open: true), item("Leaf", 3))

    expect(children(root).first[:Count]).to eq(-2)
    expect(root[:Count]).to eq(1)
  end

  it "nests a level jump and a leading deep item under the nearest shallower node" do
    root = write(item("Deep", 2), item("Top", 1), item("Jump", 3))

    expect(titles(root)).to eq(%w[Deep Top])
    expect(titles(children(root).last)).to eq(%w[Jump])
  end

  it "writes non-ASCII titles as UTF-16 text strings" do
    title = children(write(item("Übersicht €", 1))).first[:Title].b

    expect(title).to start_with("\xFE\xFF".b)
    expect(title.byteslice(2..).force_encoding(Encoding::UTF_16BE).encode(Encoding::UTF_8)).to eq("Übersicht €")
  end
end
