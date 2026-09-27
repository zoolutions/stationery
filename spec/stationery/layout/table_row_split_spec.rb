# frozen_string_literal: true

RSpec.describe Stationery::Layout::Table do
  def table(rows, **)
    described_class.new(rows, context: ctx, **)
  end

  def tall(count = 60) = Array.new(count) { |i| "line #{i + 1}" }.join("\n")
  def numbers(node) = text_of(render_layout(node).first).scan(/line (\d+)/).flatten.map(&:to_i)
  def image(height) = Stationery::Layout::Image.new(image_path("rgb.jpg"), width: 50, height:)

  it "splits a lone body row taller than a fresh page, repeating the header on each part" do
    head, tail = table([%w[Name Notes], [tall, "short"]], header: true).split(260, 100, fresh: true)

    expect([head.row_count, tail.row_count]).to eq([2, 2])
    expect(head.measure(260)).to be <= 100
    expect(strings_of(render_layout(head).first).first(3)).to eq(["Name", "Notes", "line 1"])
    expect(numbers(head)).to eq((1..numbers(head).size).to_a)
    expect(tail.cell(0, 0).content).to eq("Name")
    expect(numbers(tail).first).to eq(numbers(head).last + 1)
  end

  it "keeps splitting the rest until every line is placed in order" do
    rest = table([%w[Name Notes], [tall, "short"]], header: true)
    seen = []
    heights = []
    while rest
      head, rest = rest.split(260, 100, fresh: true)
      heights << head.measure(260)
      seen.concat(numbers(head))
    end

    expect(heights).to all(be <= 100)
    expect(seen).to eq((1..60).to_a)
  end

  it "moves the row whole when it is neither fresh nor split_rows" do
    node = table([%w[Name Notes], [tall, "short"]], header: true)

    expect(node.split(260, 100)).to eq([nil, node])
  end

  it "splits a row below rows that fit when split_rows is set" do
    node = table([%w[Name Notes], %w[fits x], [tall, "short"]], header: true, split_rows: true)
    head, tail = node.split(260, 100)

    expect(head.row_count).to eq(3)
    expect(head.cell(1, 0).content).to eq("fits")
    expect(tail.row_count).to eq(2)
  end

  it "never splits a row inside a rowspan group" do
    node = table([[{ content: tall, rowspan: 2 }, "a"], ["b"]], split_rows: true)

    expect(node.split(260, 100, fresh: true)).to eq([nil, node])
  end

  it "falls back to moving the row when no cell can split" do
    node = table([[image(300), image(250)]], split_rows: true)

    expect(node.split(260, 100)).to eq([nil, node])
  end

  it "moves an unsplittable cell to the continuation, leaving an empty cell above the cut" do
    head, tail = table([[image(300), tall]], split_rows: true).split(260, 100)

    expect(head.cell(0, 0).node(ctx)).to be_a(Stationery::Layout::Flow).and(have_attributes(children: []))
    expect(tail.cell(0, 0).node(ctx)).to be_a(Stationery::Layout::Image)
  end

  it "keeps the column widths of the table it was cut from" do
    node = table([[tall, "short"]], split_rows: true)
    head, tail = node.split(260, 100)

    expect([head.column_widths(260), tail.column_widths(260)]).to all(eq(node.column_widths(260)))
  end

  it "gives a split cell a node of its own, not the original's memo" do
    original = described_class::Cell.new("x", { padding: 2, background: "#EEEEEE" }, colspan: 2)
    original.node(ctx)
    copy = original.with_content(text_node("y"))

    expect(copy).to have_attributes(content: be_a(Stationery::Layout::Text), colspan: 2, rowspan: 1)
    expect(copy.options).to eq(original.options)
    expect(copy.node(ctx)).not_to be(original.node(ctx))
  end

  describe "in a document" do
    let(:pdf) do
      long = tall
      SpecDocument.build do
        table([%w[Name Notes], %w[before x], [long, { content: "short", background: "#EEEEEE" }]],
              header: true, split_rows: true, cell: { borders: [] })
      end.to_pdf
    end

    it "continues the row over pages with the header on each" do
      pages = reader_for(pdf).pages.map(&:text)

      expect(pages.size).to be >= 3
      expect(pages).to all(start_with("Name"))
      expect(pages.join("\n").scan(/line (\d+)/).flatten.map(&:to_i)).to eq((1..60).to_a)
    end

    it "carries the short cell's background on as tall as the fragment beside it" do
      second = reader_for(pdf).pages[1].text.scan(/line \d+/).size
      height = page_contents(pdf)[1][/[\d.]+ [\d.]+ [\d.]+ ([\d.]+) re\nf/, 1].to_f

      expect(height).to be_within(0.01).of((line_height * second) + 10)
    end
  end

  it "still moves rows that fit whole" do
    body = Array.new(30) { |i| ["row #{i + 1}", i.to_s] }
    pdf, paginator = render_layout(table([%w[Name N], *body], header: true, split_rows: true))
    pages = reader_for(pdf).pages.map(&:text)

    expect(pages.sum { |page| page.scan(/row \d+/).size }).to eq(30)
    expect(pages).to all(start_with("Name"))
    expect(paginator.warnings).to be_empty
  end
end
