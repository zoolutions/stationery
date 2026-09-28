# frozen_string_literal: true

RSpec.describe Stationery::PDF::PageSealer do
  def page(content = "q\nQ\n")
    Stationery::Page.new(size: [300, 200]).tap { it.content << content }
  end

  def slot = Stationery::Page::Slot.new(anchor: "a", x: 0, baseline: 0, width: 10, style: nil, link: nil)

  it "leaves a page open when something may still paint on it" do
    painted = page

    described_class.new.call(painted)

    expect(painted).not_to be_sealed
    expect(painted.content).to eq("q\nQ\n")
  end

  it "seals a page nothing paints on after its body" do
    painted = page

    described_class.new(final: true).call(painted)

    expect(painted.body).to be_a(Stationery::PDF::Stream)
    expect(painted.content).to be_empty
  end

  it "leaves a page open while a page number is waiting on it" do
    waiting = page.tap { it.slots << slot }

    described_class.new(final: true).call(waiting)

    expect(waiting).not_to be_sealed
  end

  context "with a writer" do
    let(:chunks) { [] }
    let(:writer) { Stationery::PDF::Writer.new(sink: ->(bytes) { chunks << bytes.dup }) }

    it "writes the body of every page at once and keeps its reference" do
      waiting = page("first\n").tap { it.slots << slot }

      described_class.new(writer:).call(waiting)

      expect(waiting.body).to eq(Stationery::PDF::Reference.new(1))
      expect(chunks.join).to start_with("%PDF-1.7\n").and include("1 0 obj\n<</Filter /FlateDecode")
        .and end_with("endobj\n")
      expect(waiting.content).to be_empty
    end

    it "writes one body after the other" do
      sealer = described_class.new(writer:)
      pages = [page("first\n"), page("second\n")].each { sealer.call(it) }

      expect(pages.map { it.body.id }).to eq([1, 2])
      expect(chunks.join.scan(/^\d+ 0 obj$/)).to eq(["1 0 obj", "2 0 obj"])
    end
  end
end
