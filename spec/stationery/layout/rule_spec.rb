# frozen_string_literal: true

RSpec.describe Stationery::Layout::Rule do
  it "draws a full-width bar of its height" do
    pdf, = render_layout(described_class.new(height: 3, color: "#FF0000"))

    expect(page_contents(pdf).first).to include("1 0 0 rg\n20 177 260 3 re")
  end
end
