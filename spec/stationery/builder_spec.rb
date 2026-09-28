# frozen_string_literal: true

RSpec.describe Stationery::Builder do
  subject(:builder) { described_class.new(book: open_sans_book) }

  it "hands its root over once and forgets it" do
    node = builder.add(Stationery::Layout::Spacer.new(10))
    root = builder.release

    expect(root.children).to eq([node])
    expect(builder.root).to be_nil
    expect(builder.release).to be_nil
  end
end
