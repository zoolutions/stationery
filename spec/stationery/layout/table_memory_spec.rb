# frozen_string_literal: true

# What a long table holds before its first page: its cells and their column
# metrics, not a text node, a placement or a structure element per cell.
RSpec.describe "what a long table holds before its pages" do # rubocop:disable RSpec/DescribeClass
  def table(rows, **, &)
    Stationery::Layout::Table.new(rows, context: ctx, **, &)
  end

  def nodes_alive(prefix)
    GC.start
    ObjectSpace.each_object(Stationery::Layout::Text).count { it.runs.first&.text&.start_with?(prefix) }
  end

  let(:rows) { [%w[Id Name City], *Array.new(300) { |i| [i.to_s, "held #{i} name", "City #{i % 7}"] }] }

  it "resolves its column widths without keeping a node per cell" do
    node = table(rows, header: true, width: :full)
    node.column_widths(400)

    expect(nodes_alive("held ")).to eq(0)
  end

  it "builds the nodes of the rows a page reaches, not of the rows after them" do
    node = table(rows, header: true)
    head, = node.split(400, 200)

    expect(head.row_count).to be < 30
    expect(nodes_alive("held ")).to be <= head.row_count
  end

  it "measures the same column metrics as a cell's node does" do
    node = table(rows, header: true)
    cells = node.cells.cells
    natural, min = Array.new(2) { Array.new(node.column_count, 0) }
    cells.each_slice(3) do |row|
      row.each_with_index do |cell, column|
        text = cell.node(ctx)
        natural[column] = [natural[column], text.natural_width + cell.horizontal].max
        min[column] = [min[column], text.min_width + cell.horizontal].max
      end
    end

    expect([node.natural_width, node.min_width]).to eq([natural.sum, min.sum])
  end

  it "places no cell on a grid to resolve the columns of a table without rowspans" do
    node = table(rows, header: true) { |t| t.row(0).weight = :bold }
    allow(Stationery::Layout::Table::Grid).to receive(:new).and_call_original

    node.column_widths(400)
    node.split(400, 200)

    expect(Stationery::Layout::Table::Grid).not_to have_received(:new).with(satisfy { it.size > 1 })
  end

  it "shares the cell options of a table until a selection changes a cell's" do
    node = table(rows) { |t| t.row(1).color = "#FF0000" }

    expect(node.cell(2, 0).options).to be(node.cell(3, 0).options)
    expect(node.cell(1, 0).options[:color]).to eq("#FF0000")
    expect(node.cell(2, 0).options).not_to have_key(:color)
  end

  it "tags a row's cells when a page paints it, not when the table is built" do
    node = table(rows, header: true)

    expect(node.cell(1, 0).tag).to be_nil
    render_layout(node)
    expect(node.cell(0, 0).tag.type).to eq(:TH)
    expect(node.cell(1, 0).tag.type).to eq(:TD)
    expect(node.cell(1, 0).row_tag).to be(node.cell(1, 2).row_tag)
  end
end
