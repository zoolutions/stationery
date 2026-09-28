# frozen_string_literal: true

RSpec.describe Stationery::Layout::Columns::Balancer do
  let(:pour_class) { Stationery::Layout::Columns::Pour }

  def balance(content, count: 2, width: 120, **)
    described_class.new(pour_class.new(content, width, count), **).call
  end

  def lines_in(poured, width: 120)
    poured.columns.map { |column| (column.measure(width) / line_height).round }
  end

  it "halves an even number of lines" do
    expect(lines_in(balance(flow(lines_of(8))))).to eq([4, 4])
  end

  it "gives the first column the odd line" do
    expect(lines_in(balance(flow(lines_of(7))))).to eq([4, 3])
  end

  it "fills three columns of the shortest height in order" do
    expect(lines_in(balance(flow(lines_of(10)), count: 3))).to eq([4, 4, 2])
    expect(lines_in(balance(flow(lines_of(9)), count: 3))).to eq([3, 3, 3])
  end

  it "leaves columns empty when there are fewer lines than columns" do
    expect(lines_in(balance(flow(lines_of(2)), count: 3))).to eq([1, 1])
  end

  it "places one column as it is" do
    poured = balance(flow(lines_of(5)), count: 1)

    expect(lines_in(poured)).to eq([5])
    expect(poured).to be_complete
  end

  it "places nothing for an empty flow" do
    poured = balance(flow)

    expect(poured.columns).to be_empty
    expect(poured).to be_complete
  end

  it "finds the shortest height for lines of unequal heights" do
    content = flow(spacer(50), lines_of(4), spacer(30), text_node("end"))
    poured = balance(content)
    heights = poured.columns.map { |column| column.measure(120) }

    expect(heights.max).to be_within(0.001).of(50 + (2 * line_height))
    expect(heights.last).to be_within(0.001).of((3 * line_height) + 30)
  end

  it "does not count a spacer dropped at the column break" do
    poured = balance(flow(lines_of(3), spacer(40), lines_of(3, prefix: "b")))

    expect(lines_in(poured)).to eq([3, 3])
  end

  it "never goes above the limit" do
    content = flow(lines_of(8))
    poured = balance(content, limit: 6 * line_height)

    expect(lines_in(poured)).to eq([4, 4])
  end

  it "returns the incomplete pour at the limit when the content does not fit" do
    poured = balance(flow(lines_of(8)), limit: 3 * line_height)

    expect(poured).not_to be_complete
    expect(lines_in(poured)).to eq([3, 3])
  end

  it "keeps the fallback when no shorter height fits" do
    tall = Stationery::Layout::Box.new(flow(lines_of(6)), height: 100)
    pour = pour_class.new(flow(tall, text_node("after")), 120, 2)
    fallback = pour.call(60, fresh: true)

    expect(fallback).to be_complete
    expect(described_class.new(pour, limit: 60, fallback:).call).to equal(fallback)
  end

  it "stops after a fixed number of probes" do
    pour = pour_class.new(flow(lines_of(8)), 120, 2)
    allow(pour).to receive(:call).and_call_original

    described_class.new(pour).call

    expect(pour).to have_received(:call).at_most(described_class::MAX_PROBES + 1).times
  end

  it "ends when a pour never places everything" do
    pour = pour_class.new(flow(lines_of(8)), 120, 2)
    complete = pour.call(1000)
    partial = pour.call(20)
    allow(pour).to receive(:call).and_return(complete, partial)

    expect(described_class.new(pour).call).to equal(complete)
    expect(pour).to have_received(:call).at_most(described_class::MAX_PROBES + 1).times
  end

  it "wraps each paragraph once per width" do
    paragraph = lines_of(30)
    allow(Stationery::Text::Wrapper).to receive(:new).and_call_original

    balance(flow(paragraph))

    expect(Stationery::Text::Wrapper).to have_received(:new).once
  end
end
