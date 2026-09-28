# frozen_string_literal: true

# What the fragments of a table cut by page breaks keep from the table they
# were cut from: its column metrics, and the widths and heights it measured.
RSpec.describe Stationery::Layout::Table, "#split" do
  def table(rows, **, &)
    described_class.new(rows, context: ctx, **, &)
  end

  # The x each page's header cells start at.
  def header_columns(pdf, header)
    reader_for(pdf).pages.map do |page|
      header.map { |title| page.runs.find { |run| run.text == title }.then { |run| run && run.origin.x.round(3) } }
    end
  end

  let(:late_wide) do
    [%w[Id Name], *Array.new(14) { |i| [i.to_s, "n"] }, ["15", "a much wider name than any before it"]]
  end

  it "resolves the same column widths on every page, from the whole table" do
    node = table(late_wide, header: true)
    head, tail = node.split(260, 100)

    expect(head.column_widths(260)).to eq(node.column_widths(260))
    expect(tail.column_widths(260)).to eq(node.column_widths(260))
    expect([head, tail].map(&:natural_width)).to all(eq(node.natural_width))
  end

  it "starts every column at the same x on every page" do
    pdf, paginator = render_layout(table(late_wide, header: true))
    columns = header_columns(pdf, %w[Id Name])

    expect(columns.size).to be > 1
    expect(columns.uniq).to eq([columns.first])
    expect(columns.first).to all(be_a(Float))
    expect(paginator.warnings).to be_empty
  end

  it "measures nothing again for a page break at the same width" do
    node = table(Array.new(20) { |i| ["row #{i}"] }, header: true)
    _head, tail = node.split(200, 100)
    cell = node.cell(19, 0)
    allow(cell).to receive(:measure).and_call_original
    allow(described_class::Grid).to receive(:new).and_call_original

    expect(tail.measure(200)).to eq(node.measure(200) - node.send(:row_heights, 200)[1, 3].sum)
    _next, rest = tail.split(200, 100)
    rest.measure(200)

    expect(cell).not_to have_received(:measure)
  end

  it "places the rows still to come on no grid while no cell spans rows" do
    node = table(Array.new(40) { |i| ["row #{i}", i.to_s] }, header: true)
    node.measure(200)
    allow(described_class::Grid).to receive(:new).and_call_original

    _head, tail = node.split(200, 100)
    _next, rest = tail.split(200, 100)
    rest.split(200, 100)
    expect(described_class::Grid).not_to have_received(:new)

    expect(rest.column_count).to eq(2)
    expect(rest.cell(1, 1)).to be(node.cell(node.row_count - rest.row_count + 1, 1))
    expect(described_class::Grid).to have_received(:new).once
  end

  it "cuts a table whose cells span rows only where no span crosses" do
    rows = [%w[A B], *Array.new(8) { |i| [[{ content: "span #{i}", rowspan: 2 }, "x"], ["y"]] }.flatten(1)]
    node = table(rows, header: true)
    head, tail = node.split(200, 5 * (line_height + 10))

    expect(head.row_count).to eq(5)
    expect(tail.row_count).to eq(13)
    expect(tail.send(:grid).boundaries).to eq([0, 1, 3, 5, 7, 9, 11, 13])
  end

  it "resolves and measures again when a fragment is laid out at another width" do
    rows = [%w[Id Name]] + Array.new(12) { |i| [i.to_s, "a name that wraps when the column is narrow #{i}"] }
    node = table(rows, header: true, width: :full)
    _head, tail = node.split(260, 100)
    fresh = table([rows[0], *rows.last(tail.row_count - 1)], header: true, width: :full,
                                                             widths: tail.column_widths(140))

    expect(tail.column_widths(140).sum).to be_within(1e-9).of(140)
    expect(tail.column_widths(140)).not_to eq(tail.column_widths(260))
    expect(tail.measure(140)).to be > tail.measure(260)
    expect(tail.measure(140)).to be_within(1e-9).of(fresh.measure(140))
  end

  it "carries the heights of rows that span, cut only where no span crosses" do
    rows = [%w[A B C],
            *Array.new(6) do |i|
              [[{ content: "span #{i}", rowspan: 2 }, "x", "y"], [{ content: "wide #{i}", colspan: 2 }]]
            end.flatten(1)]
    node = table(rows, header: true, widths: [80, 60, 60])
    head, tail = node.split(200, 110)
    kept = head.row_count - 1
    fresh = table([rows[0], *rows.drop(1 + kept)], header: true, widths: [80, 60, 60])

    expect(kept).to be_even
    expect(head.measure(200) + tail.measure(200)).to be_within(1e-9).of(node.measure(200) + line_height + 10)
    expect(tail.measure(200)).to be_within(1e-9).of(fresh.measure(200))
    expect(tail.send(:grid).boundaries).to eq(fresh.send(:grid).boundaries)
  end

  it "measures the two parts of a cut row and carries the rest" do
    tall = Array.new(12) { |i| "line #{i}" }.join("\n")
    rows = [%w[Name Notes], %w[a short], ["b", tall], %w[c short]]
    node = table(rows, header: true, split_rows: true, widths: [60, 140])
    head, tail = node.split(200, 120)
    heights = node.send(:row_heights, 200)

    expect(head.row_count).to eq(3)
    expect(tail.row_count).to eq(3)
    expect(head.measure(200)).to be <= 120
    expect(head.send(:row_heights, 200).first(2)).to eq(heights.first(2))
    expect(tail.send(:row_heights, 200).values_at(0, 2)).to eq(heights.values_at(0, 3))
    expect(head.send(:row_heights, 200)[2] + tail.send(:row_heights, 200)[1])
      .to be_within(1e-9).of(heights[2] + 10)
    expect(head.column_widths(200)).to eq([60, 140])
  end

  it "keeps the header rows on a continued fragment and the table's tag" do
    node = table(late_wide, header: true)
    head, tail = node.split(260, 100)

    expect([head.tag, tail.tag]).to all(be(node.tag))
    expect(tail.cell(0, 0)).to be(node.cell(0, 0))
    expect(tail.cell(1, 0)).to be(node.cell(head.row_count, 0))
    expect(node.cell(0, 0).tag.type).to eq(:TH)
    expect(tail.cell(1, 0).tag).to be(node.cell(head.row_count, 0).tag)
  end

  it "tags each cell once, however many pages the table takes" do
    created = Hash.new(0)
    allow(Stationery::Tagging::Element).to receive(:new).and_wrap_original do |original, type, **options|
      created[type] += 1
      original.call(type, **options)
    end
    node = table([%w[Name N], *Array.new(30) { |i| ["row #{i}", i.to_s] }], header: true)
    pdf, = render_layout(node)

    expect(page_count(pdf)).to be > 2
    expect(created.slice(:Table, :TR, :TH, :TD)).to eq(Table: 1, TR: 31, TH: 2, TD: 60)
  end
end
