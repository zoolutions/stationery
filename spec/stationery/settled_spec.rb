# frozen_string_literal: true

# What Document.finalize! and Stationery.finalize! make of the settings an
# app gave at boot: frozen as far as they can be, and what the app still
# holds left as it is.

# Blocks written where a document's are, in a class or module body: their
# self is the module.
module SettledBlocks
  def self.page_number = proc { |page| page.number.to_s }
  def self.using(value) = proc { value }
end

RSpec.describe Stationery, ".settled" do
  # Keeps state, as a shaper or an instrumenter may: freezing it breaks it.
  let(:stateful) do
    Class.new do
      attr_reader :calls

      def initialize(io)
        @io = io
        @calls = []
      end

      def call(text) = @calls << text
    end
  end

  it "answers a Hash, an Array and a String frozen, leaving the ones it was given alone" do
    name = +"Invoice"
    list = [+"a"]
    given = { metadata: { title: name }, fallbacks: list }
    settled = described_class.settled(given)

    expect(settled).to eq(given)
    expect(settled).to be_frozen
    expect(settled[:metadata]).to be_frozen
    expect(settled[:metadata][:title]).to be_frozen
    expect(settled[:fallbacks]).to all(be_frozen)
    expect([given, given[:metadata], name, list, list.first]).to all(satisfy { !it.frozen? })
  end

  it "makes plain settings Ractor-shareable" do
    region = Stationery::Region.new(slot: :footer, height: nil, gap: 8, on: :all, block: SettledBlocks.page_number)
    settled = described_class.settled({ regions: [region], at: Time.utc(2026, 1, 1), size: [1, +"2"] })

    expect(Ractor.shareable?(settled)).to be(true)
    expect(settled[:regions].first).to eq(region)
  end

  it "makes a block shareable when it uses nothing unshareable from around it" do
    block = SettledBlocks.page_number

    expect(described_class.settled(block)).to be(block)
    expect(Ractor.shareable?(block)).to be(true)
  end

  it "keeps a block that uses an unshareable local as it is" do
    draft = +"draft"
    block = SettledBlocks.using(draft)

    expect(described_class.settled([block]).first).to be(block)
    expect(Ractor.shareable?(block)).to be(false)
    expect(draft).not_to be_frozen
  end

  it "keeps an object that is not shareable as it is, and never freezes what it holds" do
    io = StringIO.new
    object = stateful.new(io)
    settled = described_class.settled({ shaping: { shaper: object } })

    expect(settled[:shaping][:shaper]).to be(object)
    expect([object, io, $stdout]).to all(satisfy { !it.frozen? })
    expect { object.call("still works") }.to change(object, :calls).to(["still works"])
  end

  it "answers what is shareable already as it is" do
    shareable = Ractor.make_shareable({ page: { size: :a4 } })

    expect(described_class.settled(shareable)).to be(shareable)
  end
end
