# frozen_string_literal: true

RSpec.describe Stationery::Monochrome::Dither do
  # The bits of a packed image as rows of "1" (white) and "0" (black).
  def rows(packed, width) = packed.unpack1("B*").scan(/.{#{((width + 7) / 8) * 8}}/).map { |row| row[0, width] }
  def grey(width, height, value) = ([value] * width * height).pack("C*")

  it "leaves black black and white white, whatever the method" do
    %i[floyd_steinberg ordered threshold].each do |method|
      expect(rows(described_class.call(grey(3, 2, 0), 3, 2, method), 3)).to eq(%w[000 000])
      expect(rows(described_class.call(grey(3, 2, 255), 3, 2, method), 3)).to eq(%w[111 111])
    end
  end

  it "cuts at half with :threshold" do
    ramp = [0, 100, 127, 128, 200, 255].pack("C*")

    expect(rows(described_class.call(ramp, 6, 1, :threshold), 6)).to eq(%w[000111])
  end

  it "pads each row to a whole byte" do
    expect(described_class.call(grey(9, 2, 255), 9, 2, :threshold).bytesize).to eq(4)
  end

  it "turns a mid grey into about half black dots, spread out" do
    %i[floyd_steinberg ordered].each do |method|
      bits = rows(described_class.call(grey(16, 16, 128), 16, 16, method), 16).join

      expect(bits.count("0")).to be_within(16).of(128)
      expect(bits).not_to include("0000")
    end
  end

  it "keeps the share of black of a light grey" do
    bits = rows(described_class.call(grey(32, 32, 230), 32, 32, :floyd_steinberg), 32).join

    expect(bits.count("0").fdiv(bits.size)).to be_within(0.03).of(25.0 / 255)
  end

  it "refuses a method it does not know" do
    expect { described_class.call(grey(1, 1, 0), 1, 1, :atkinson) }.to raise_error(ArgumentError, /atkinson/)
  end
end
