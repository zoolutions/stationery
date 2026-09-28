# frozen_string_literal: true

# A render that writes no structure tree builds no structure elements: the
# layout nodes of an untagged document carry nil where a tagged one carries
# a Tagging::Element, and the canvas treats nil as it treats an element it
# cannot attach. The bytes written are the same either way (the metrics gate
# holds them).
RSpec.describe "structure elements of a render that is not tagged" do # rubocop:disable RSpec/DescribeClass
  let(:document) do
    logo = File.expand_path("../../fixtures/images/rgb.jpg", __dir__)
    SpecDocument.build do
      table_of_contents
      text "Title", heading: 1, bookmark: "Title"
      text "Body with a <a href='https://example.com'>link</a>", markup: true
      table([%w[a b], %w[c d]], header: true)
      box(role: :section, link: "https://example.com") { text "in a box" }
      ul { li "one"; li "two" } # rubocop:disable Style/Semicolon
      ol(format: :decimal) { li "first" }
      image logo, width: 20, alt: "Logo"
      svg '<svg viewBox="0 0 10 10"><rect width="5" height="5"/></svg>', width: 10, alt: "Square"
      text_field "name", value: "Astrid"
    end
  end

  def elements_built
    count = 0
    allow(Stationery::Tagging::Element).to receive(:new).and_wrap_original do |original, *args, **options|
      count += 1
      original.call(*args, **options)
    end
    yield
    count
  end

  it "builds none for a render without a tree" do
    expect(elements_built { document.to_pdf }).to eq(0)
  end

  it "builds one per node for a tagged render" do
    expect(elements_built { document.to_pdf(tagged: true) }).to be >= 20
  end

  it "keeps the structure tree of a tagged render" do
    types = struct_types(document.to_pdf(tagged: true)).flatten

    expect(types).to include(:TOC, :TOCI, :H1, :P, :Link, :Table, :TR, :TH, :TD, :Sect, :L, :LI, :LBody, :Lbl,
                             :Figure, :Form)
  end

  it "builds the elements of a tagged context, and none for an untagged one" do
    book = open_sans_book
    context = Stationery::Layout::Context.new(book:, style: base_style, tagged: true)

    expect(context.element(:P)).to be_a(Stationery::Tagging::Element)
    expect(context.with(style: base_style(size: 12)).element(:P).type).to eq(:P)
    expect(Stationery::Layout::Context.new(book:, style: base_style, tagged: false).element(:P)).to be_nil
  end
end
