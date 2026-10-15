# frozen_string_literal: true

RSpec.describe Stationery::Barcode::ReedSolomon do
  # The generator's roots start at α^first_root, so two coders over the same
  # field but from other roots divide by other polynomials, and neither may
  # be handed the other's.
  it "keeps the divisors of each first root apart" do
    from_zero = described_class.new(0x11D, 0)
    from_one = described_class.new(0x11D, 1)

    expect(from_zero.divisor(7)).to eq(described_class::QR.divisor(7))
    expect(from_one.divisor(7)).not_to eq(from_zero.divisor(7))
    expect(from_zero.divisor(7)).to eq(described_class::QR.divisor(7))
  end
end
