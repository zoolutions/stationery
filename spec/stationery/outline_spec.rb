# frozen_string_literal: true

RSpec.describe Stationery::Outline do
  subject(:outline) { described_class.new }

  let(:destination) { Stationery::Structure::Destination }

  it "records entries in build order with automatic anchors" do
    intro = outline.add("Introduction")
    scope = outline.add(:Scope, level: 2, open: true)

    expect(outline.entries).to eq([intro, scope])
    expect(intro).to eq(described_class::Entry.new("Introduction", 1, "__bookmark-1", false))
    expect(scope).to eq(described_class::Entry.new("Scope", 2, "__bookmark-2", true))
  end

  it "rejects levels below 1" do
    expect { outline.add("x", level: 0) }.to raise_error(ArgumentError, /level/)
  end

  it "resolves entries against destinations, skipping those never painted" do
    outline.add("Painted", open: true)
    outline.add("Lost", level: 2)

    expect(outline.resolve("__bookmark-1" => destination.new(2, 700)))
      .to eq([described_class::Item.new("Painted", 1, destination.new(2, 700), true)])
  end
end
