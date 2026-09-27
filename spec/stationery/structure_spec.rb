# frozen_string_literal: true

RSpec.describe Stationery::Structure do
  let(:warnings) { Stationery::Warnings.new }
  let(:pages) { Array.new(2) { Stationery::Page.new(size: [100, 100]) } }
  let(:destination) { described_class::Destination }

  def canvas(index, template: false) = Stationery::Canvas.new(pages[index], nil, template:)

  it "maps each anchor to its page and top, the first definition winning" do
    canvas(0).anchor("a", 10)
    canvas(1).anchor("b", 30)
    canvas(1).anchor("a", 50)

    expect(described_class.resolve(pages, warnings:))
      .to eq("a" => destination.new(0, 90), "b" => destination.new(1, 70))
    expect(warnings.to_a).to eq([Stationery::Warnings::DuplicateAnchor.new(name: "a", page: 2)])
  end

  it "resolves anchors drawn by page templates without calling them duplicates" do
    pages.each_index { |i| canvas(i, template: true).anchor("top", 0) }

    expect(described_class.resolve(pages, warnings:)).to eq("top" => destination.new(0, 100))
    expect(warnings).to be_empty
  end

  it "prefers a body anchor over a template anchor of the same name" do
    canvas(0, template: true).anchor("x", 0)
    canvas(1).anchor("x", 20)

    expect(described_class.resolve(pages, warnings:)).to eq("x" => destination.new(1, 80))
  end

  it "points internal links at their destination and drops unresolved ones with a warning" do
    canvas(1).anchor("b", 0)
    canvas(0).link(0, 0, 10, 10, "#b")
    canvas(0).link(0, 0, 10, 10, "#missing")
    canvas(0).link(0, 0, 10, 10, "https://example.com")
    described_class.resolve(pages, warnings:)

    expect(pages[0].annotations).to eq([
                                         { rect: [0, 90, 10, 100], dest: destination.new(1, 100) },
                                         { rect: [0, 90, 10, 100], url: "https://example.com" }
                                       ])
    expect(warnings.to_a).to eq([Stationery::Warnings::UnresolvedLink.new(name: "missing", page: 1)])
  end

  it "fills page-number slots right-aligned and leaves unknown ones blank" do
    resources = Stationery::Resources.new
    style = base_style(size: 10)
    canvas(1).anchor("b", 0)
    canvas(0).number_slot("b", x: 50, baseline: 20, width: 30, style:, link: [0, 10, 80, 12])
    canvas(0).number_slot("missing", x: 50, baseline: 40, width: 30, style:, link: [0, 30, 80, 12])
    described_class.resolve(pages, warnings:, resources:, book: open_sans_book)
    x = 80 - open_sans_book.resolve(style).first.width_of("2", 10)

    expect(pages[0].content.scan("Tj").size).to eq(1)
    expect(pages[0].content).to include("#{Stationery::PDF::Serializer.number(x)} 80 Td")
    expect(pages[0].resource_names[:Font]).to eq([:F1])
    expect(pages[0].annotations).to eq([{ rect: [0, 78, 80, 90], dest: destination.new(1, 100) }])
    expect(warnings).to be_empty
  end
end
