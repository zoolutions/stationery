# frozen_string_literal: true

RSpec.describe Stationery::Layout::Mark do
  let(:recorder) do
    Class.new do
      attr_reader :calls

      def initialize = @calls = []
      def anchor(name, y) = @calls << [:anchor, name, y]
    end.new
  end

  it "measures, sizes and splits like the node it wraps" do
    child = lines_of(3)
    mark = described_class.new(child, ["intro"])

    expect(mark.measure(200)).to eq(child.measure(200))
    expect([mark.natural_width, mark.min_width]).to eq([child.natural_width, child.min_width])
    expect(mark.fixed_width(100)).to be_nil
    expect([mark.splittable?, mark.page_break?, mark.avoid_break?]).to eq([true, false, false])
  end

  it "forwards keep_with_next and break_inside to the wrapped node" do
    child = spacer(10)
    mark = described_class.new(child, ["a"])
    mark.keep_with_next = true
    mark.break_inside = :avoid

    expect([child.keep_with_next, child.break_inside]).to eq([true, :avoid])
    expect([mark.keep_with_next, mark.break_inside]).to eq([true, :avoid])
  end

  it "keeps the anchor on the first fragment of a split" do
    mark = described_class.new(lines_of(10), ["intro"])
    head, tail = mark.split(200, line_height * 3)

    expect(head).to be_a(described_class)
    expect(head.names).to eq(["intro"])
    expect(tail).not_to be_a(described_class)
  end

  it "passes an empty head through" do
    head, tail = described_class.new(Stationery::Layout::Rule.new(height: 50), ["r"]).split(200, 10)

    expect(head).to be_nil
    expect(tail).to be_a(Stationery::Layout::Rule)
  end

  it "records each name at its top before painting the child" do
    child = instance_double(Stationery::Layout::Node, paint: nil)
    described_class.new(child, %w[a b]).paint(recorder, 5, 40, 100)

    expect(recorder.calls).to eq([[:anchor, "a", 40], [:anchor, "b", 40]])
    expect(child).to have_received(:paint).with(recorder, 5, 40, 100, nil)
  end

  it "wraps an empty node for a standalone anchor that travels with what follows" do
    mark = described_class.standalone("appendix")

    expect(mark.measure(100)).to eq(0)
    expect(mark.keep_with_next).to be(true)
    expect(mark.child).not_to be_a(Stationery::Layout::Spacer)
    mark.paint(recorder, 0, 12, 100)
    expect(recorder.calls).to eq([[:anchor, "appendix", 12]])
  end
end
