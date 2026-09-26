# frozen_string_literal: true

RSpec.describe Stationery::Text::RunsBuilder do
  it "builds the same runs as the equivalent markup" do
    built = described_class.build(base_style) do
      plain "Total "
      b "due"
      plain " — "
      link("https://pay.test") { i "pay now" }
      color("#FF0000") { plain "!" }
      size(7) { u "small" }
    end
    parsed = Stationery::Text::Markup.parse(
      "Total <b>due</b> — <link href='https://pay.test'><i>pay now</i></link>" \
      "<color rgb='#FF0000'>!</color><font size='7'><u>small</u></font>", base_style
    )

    expect(built).to eq(parsed)
  end

  it "treats a string returned from the block as plain text" do
    expect(described_class.build(base_style) { "hello" }.map(&:text)).to eq(["hello"])
  end
end
