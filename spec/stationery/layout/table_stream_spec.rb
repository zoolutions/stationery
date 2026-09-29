# frozen_string_literal: true

# A table whose rows come from an Enumerator and whose every column has a
# width reads its rows as pages reach them: nothing before its first page,
# the rows of one page (and the one after it) for each page.
RSpec.describe "a table streamed from an Enumerator" do # rubocop:disable RSpec/DescribeClass
  let(:layout_table) { Stationery::Layout::Table }
  let(:pulled) { [] }
  let(:source) do
    Enumerator.new do |rows|
      rows << %w[Id Name City]
      300.times do |i|
        pulled << i
        rows << [i.to_s, "streamed #{i} name", "City #{i % 7}"]
      end
    end
  end
  let(:widths) { [40, 120, 80] }

  def table(rows, **, &)
    layout_table.new(rows, context: ctx, **, &)
  end

  describe ".streams?" do
    it "streams an Enumerator, lazy or not, whose every column has a width" do
      expect(layout_table.streams?(source, widths)).to be(true)
      expect(layout_table.streams?(source.lazy.map(&:itself), [0.25, 0.5, 0.25])).to be(true)
    end

    it "reads an Array, or an Enumerator with a flexible column, whole" do
      expect(layout_table.streams?(source.to_a, widths)).to be(false)
      expect(layout_table.streams?(source, [40, nil, 80])).to be(false)
      expect(layout_table.streams?(source, nil)).to be(false)
    end
  end

  it "reads no row when it is built, and the rows of a page when a page reaches them" do
    node = table(source.lazy, widths:, header: true)

    expect(pulled).to be_empty
    head, tail = node.split(400, 200)

    expect(head.row_count).to be_between(2, 30)
    expect(pulled.size).to eq(head.row_count) # the rows on the page and the one after them
    expect(tail).not_to be_nil
  end

  it "cuts the same pages as the Array of the same rows" do
    streamed = table(source.lazy, widths:, header: true)
    whole = table(source.to_a, widths:, header: true)
    pulled.clear
    pages = lambda do |node|
      Array.new(4) do
        head, node = node.split(400, 200)
        head.row_count
      end
    end

    expect(pages.call(streamed)).to eq(pages.call(whole))
  end

  it "keeps only the rows of the pages not painted yet" do
    node = table(source.lazy, widths:, header: true)
    30.times { _, node = node.split(400, 200) }
    GC.start
    alive = ObjectSpace.each_object(Stationery::Layout::Table::Cell).count { it.content.to_s.start_with?("streamed") }

    expect(pulled.size).to be > 150
    expect(alive).to be < 40
  end

  it "resolves its columns without measuring a cell" do
    node = table(source.lazy, widths:, header: true)
    node.split(400, 200)

    expect(node.column_widths(400)).to eq(widths)
    expect(node.cell(1, 1).instance_variable_get(:@natural_width)).to be_nil
  end

  describe "selections" do
    it "styles the rows it reads by their index from the start of the table" do
      node = table(source.lazy, widths:, header: true) do |t|
        t.row(0).weight = :bold
        t.rows(2..3).columns(1..).color = "#FF0000"
        t.columns(2).align = :right
        t.zebra(from: 1, color: "#EEEEEE")
      end
      node.split(400, 400)

      expect(node.cell(0, 0).options[:weight]).to eq(:bold)
      expect([node.cell(2, 0), node.cell(2, 1), node.cell(3, 2)].map { it.options[:color] })
        .to eq([nil, "#FF0000", "#FF0000"])
      expect(node.cell(4, 2).options[:align]).to eq(:right)
      expect((1..4).map { node.cell(it, 0).options[:background] }).to eq(["#EEEEEE", nil, "#EEEEEE", nil])
    end

    it "refuses a row counted from the end, which is not known until the last row is read" do
      expect { table(source.lazy, widths:) { |t| t.row(-1).weight = :bold } }
        .to raise_error(ArgumentError, /from its end/)
      expect { table(source.lazy, widths:) { |t| t.rows(1..-2).weight = :bold } }
        .to raise_error(ArgumentError, /from its end/)
      expect { table(source.lazy, widths:) { |t| t.cells.rows([0, -1]).weight = :bold } }
        .to raise_error(ArgumentError, /from its end/)
    end

    it "selects columns from either end, their count being the widths'" do
      node = table(source.lazy, widths:) { |t| t.columns(-1).align = :right }
      node.split(400, 100)

      expect([node.cell(1, 2), node.cell(1, 1)].map { it.options[:align] }).to eq([:right, nil])
    end
  end

  it "refuses a cell spanning rows when it reaches it" do
    rows = [%w[a b c], [{ content: "x", rowspan: 2 }, "y", "z"], %w[p q]].each
    node = table(rows, widths:)

    expect { node.split(400, 400) }.to raise_error(ArgumentError, /spans rows/)
  end

  it "refuses a row with more columns than it has widths" do
    node = table([%w[a b c d]].each, widths:)

    expect { node.split(400, 400) }.to raise_error(ArgumentError, /4 columns.*3 widths/)
  end

  it "keeps cells spanning columns within a row" do
    rows = [%w[a b c], [{ content: "wide", colspan: 2 }, "z"]]
    streamed = table(rows.each, widths:)
    streamed.split(400, 400)

    expect(streamed.cell(1, 1)).to be(streamed.cell(1, 0))
    expect(streamed.cell(1, 2).content).to eq("z")
  end
end
