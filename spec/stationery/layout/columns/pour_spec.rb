# frozen_string_literal: true

RSpec.describe Stationery::Layout::Columns::Pour do
  def pour(content, count: 2) = described_class.new(content, 120, count)
  def lines_in(poured) = poured.columns.map { |column| (column.measure(120) / line_height).round }

  it "fills each column before the next" do
    poured = pour(flow(lines_of(7))).call(5 * line_height)

    expect(lines_in(poured)).to eq([5, 2])
    expect(poured).to be_complete
    expect(poured.height(120)).to be_within(0.001).of(5 * line_height)
  end

  it "hands back what the columns did not take" do
    poured = pour(flow(lines_of(7))).call(2 * line_height)

    expect(lines_in(poured)).to eq([2, 2])
    expect(poured.rest.measure(120)).to be_within(0.001).of(3 * line_height)
  end

  it "measures the flow in one column" do
    expect(pour(flow(lines_of(7))).total).to be_within(0.001).of(7 * line_height)
  end

  it "ends at a column that places nothing" do
    tall = Stationery::Layout::Box.new(flow(lines_of(6)), height: 100)
    poured = pour(flow(text_node("first"), tall), count: 3).call(50)

    expect(poured.columns.size).to eq(1)
    expect(poured.rest.children).to eq([tall])
  end

  it "keeps a child too tall for a column at the top of a page" do
    tall = Stationery::Layout::Box.new(flow(lines_of(6)), height: 100)
    poured = pour(flow(tall, text_node("after"))).call(50, fresh: true)

    expect(poured.columns.map { |column| column.measure(120) }).to eq([100, line_height])
    expect(poured).to be_complete
  end

  describe "#first" do
    it "cuts the first column and pours what it leaves through the columns after it" do
      head, rest = pour(flow(lines_of(7)), count: 3).first(3 * line_height)

      expect(head.measure(120)).to be_within(0.001).of(3 * line_height)
      expect([rest.count, rest.width]).to eq([2, 120])
      expect(rest.total).to be_within(0.001).of(4 * line_height)
    end

    it "leaves no pour when the first column takes everything" do
      head, rest = pour(flow(lines_of(3)), count: 3).first(3 * line_height)

      expect(head.measure(120)).to be_within(0.001).of(3 * line_height)
      expect(rest).to be_nil
    end

    it "has no first column when nothing fits the height" do
      tall = Stationery::Layout::Box.new(flow(lines_of(6)), height: 100)
      head, rest = pour(flow(tall, text_node("after")), count: 3).first(50)

      expect(head).to be_nil
      expect(rest.total).to be_within(0.001).of(100 + line_height)
    end
  end

  it "is empty and complete for an empty flow" do
    poured = pour(flow).call(100)

    expect(poured.columns).to be_empty
    expect(poured).to be_complete
    expect(poured.height(120)).to eq(0)
  end
end
