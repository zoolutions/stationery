# frozen_string_literal: true

RSpec.describe Stationery::Layout::Table::Grid do
  def cells(rows)
    rows.map do |row|
      row.map do |value|
        spec = value.is_a?(Hash) ? value : { content: value }
        Stationery::Layout::Table::Cell.new(spec[:content], {}, colspan: spec.fetch(:colspan, 1),
                                                                rowspan: spec.fetch(:rowspan, 1))
      end
    end
  end

  def grid(rows) = described_class.new(cells(rows))

  it "places a colspan over the following columns" do
    placed = grid([[{ content: "a", colspan: 2 }, "b"], %w[c d e]])

    expect(placed.column_count).to eq(3)
    expect(placed.at(0, 1).content).to eq("a")
    expect(placed.at(0, 2).content).to eq("b")
    expect(placed.at(1, 2).content).to eq("e")
    expect([placed.at(-1, 0), placed.at(0, -1), placed.at(2, 0)]).to eq([nil, nil, nil])
  end

  it "skips slots a rowspan from above covers" do
    placed = grid([[{ content: "a", rowspan: 2 }, "b"], ["c"]])

    expect(placed.at(1, 0).content).to eq("a")
    expect(placed.at(1, 1).content).to eq("c")
    expect(placed.boundaries).to eq([0, 2])
  end

  it "clamps a rowspan that runs past the last row" do
    placed = grid([[{ content: "a", rowspan: 5 }, "b"], ["c"]])

    expect(placed.placements.first.rowspan).to eq(2)
    expect(placed.row_count).to eq(2)
    expect(placed.at(2, 0)).to be_nil
  end

  it "keeps a cut out of every row a taller rowspan covers" do
    placed = grid([[{ content: "a", rowspan: 3 }, "b"], ["c"], ["d"], %w[e f], [{ content: "g", rowspan: 2 }, "h"],
                   ["i"]])

    expect(placed.boundaries).to eq([0, 3, 4, 6])
  end

  it "treats every row as a boundary without rowspans" do
    expect(grid([%w[a b], %w[c d]]).boundaries).to eq([0, 1, 2])
  end

  it "spreads a spanning cell's excess metric evenly over its columns" do
    placed = grid([[{ content: 30, colspan: 2 }], [5, 15]])

    expect(placed.column_metric { |p| p.cell.content }).to eq([10.0, 20.0])
    expect(grid([[{ content: 10, colspan: 2 }], [5, 15]]).column_metric { |p| p.cell.content }).to eq([5, 15])
  end

  it "adds a tall rowspan's excess height to its last row" do
    placed = grid([[{ content: 50, rowspan: 2 }, 10], [10]])

    expect(placed.row_heights([1, 1]) { |p, _width| p.cell.content }).to eq([10, 40])
  end

  it "measures spanning cells at the sum of their column widths" do
    placed = grid([[{ content: "a", colspan: 2 }], %w[b c]])
    widths = []
    placed.row_heights([10, 20]) do |p, width|
      widths << [p.cell.content, width]
      0
    end

    expect(widths).to include(["a", 30], ["b", 10], ["c", 20])
  end
end
