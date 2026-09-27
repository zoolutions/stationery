# frozen_string_literal: true

RSpec.describe Stationery::Text::Style do
  it "has sensible defaults" do
    style = described_class.new(family: "Open Sans")

    expect(style).to have_attributes(size: 10, weight: :regular, style: :normal, color: "#000000", letter_spacing: 0,
                                     underline: false, strikethrough: false, script: nil, link: nil,
                                     kerning: true)
  end

  it "scales sub- and superscript and raises or lowers the baseline" do
    sup = described_class.new(family: "X", size: 12, script: :sup)
    sub = described_class.new(family: "X", size: 12, script: :sub)

    expect(sup.render_size).to be_within(0.01).of(7)
    expect(sup.rise).to be > 0
    expect(sub.rise).to be < 0
    expect(described_class.new(family: "X", size: 12)).to have_attributes(render_size: 12, rise: 0)
  end
end
