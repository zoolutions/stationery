# frozen_string_literal: true

RSpec.describe Stationery::Layout::Table do
  def table(rows, **, &)
    described_class.new(rows, context: ctx, cell: { padding: 0, borders: [] }, **, &)
  end

  def width_of(text) = open_sans_book.resolve(base_style).first.width_of(text, 10)

  it "reads colspan, rowspan and extra options from a Hash cell" do
    node = table([[{ content: "Total", colspan: 2, rowspan: 1, align: :right }, "x"]])
    total = node.cell(0, 1)

    expect([total.content, total.colspan, total.rowspan]).to eq(["Total", 2, 1])
    expect(total.options).to include(align: :right, padding: 0)
    expect(node.column_count).to eq(3)
    expect(node.cell(0, 2).content).to eq("x")
  end

  it "grows the spanned columns evenly for a colspan wider than them" do
    heading = "a much longer spanning heading"
    widths = table([[{ content: heading, colspan: 2 }], %w[a bbbb]]).column_widths(260)

    expect(widths.sum).to be_within(0.01).of(width_of(heading))
    expect(widths[1] - widths[0]).to be_within(0.01).of(width_of("bbbb") - width_of("a"))
  end

  it "keeps column widths when a colspan fits its columns" do
    spanned = table([[{ content: "x", colspan: 2 }], %w[aaaa bbbb]]).column_widths(260)

    expect(spanned).to eq(table([%w[aaaa bbbb]]).column_widths(260))
  end

  it "adds a tall rowspan's excess height to the last row it spans" do
    node = table([[{ content: "1\n2\n3\n4", rowspan: 2 }, "a"], ["b"], ["c"]])
    pdf, = render_layout(node)
    ys = positions_of(pdf).map(&:last)

    expect(node.measure(260)).to be_within(0.01).of(line_height * 5)
    expect(ys[-2] - ys[-1]).to be_within(0.01).of(line_height * 3)
  end

  it "aligns a spanning cell's content within the combined columns" do
    node = table([[{ content: "Mid", colspan: 2, align: :center }], %w[a b]], width: :full, widths: [100, 160])
    pdf, = render_layout(node)

    expect(positions_of(pdf).first.first + (width_of("Mid") / 2)).to be_within(0.01).of(150)
  end

  it "fills a rowspan cell's background over every row it spans" do
    node = table([[{ content: "x", rowspan: 2, background: "#EEEEEE" }, "a"], ["b"]])
    pdf, = render_layout(node)
    height = page_contents(pdf).first[/[\d.]+ [\d.]+ [\d.]+ ([\d.]+) re\nf/, 1].to_f

    expect(height).to be_within(0.01).of(line_height * 2)
  end

  it "breaks before a rowspan rather than cutting through it" do
    first = Array.new(9) { |i| "top #{i}" }.join("\n")
    node = described_class.new([[first], [{ content: "span", rowspan: 2 }, "b"], ["c"]], context: ctx)
    pdf, = render_layout(node)
    pages = reader_for(pdf).pages.map(&:text)

    expect(pages.size).to eq(2)
    expect(pages.first).to include("top 8")
    expect(pages.first).not_to include("span")
    expect(pages.last).to include("span").and include("c")
  end

  it "selects a spanning cell once" do
    node = table([["x", { content: "a", rowspan: 2 }], ["y"]])
    spanning = node.cell(0, 1)
    allow(spanning).to receive(:[]=).and_call_original
    node.column(1).align = :right

    expect(node.cells.cells.size).to eq(3)
    expect(spanning).to have_received(:[]=).once
    expect(spanning.options[:align]).to eq(:right)
  end

  it "rejects a header whose rowspan runs into the body" do
    rows = [[{ content: "h", rowspan: 2 }, "x"], ["y"], ["z"]]

    expect { table(rows, header: 1) }.to raise_error(ArgumentError, /header/)
  end
end
