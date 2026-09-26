# frozen_string_literal: true

RSpec.describe Stationery::Layout::CanvasNode do
  it "reserves its height and hands the block a clipped canvas and rect" do
    seen = nil
    node = described_class.new(height: 40) do |canvas, rect|
      seen = rect
      canvas.circle(rect.x + 10, rect.y + 10, 5, fill: "#000")
    end
    pdf, = render_layout(flow(spacer(10), node))

    expect(node.measure(100)).to eq(40)
    expect(seen).to eq(Stationery::Rect.new(20, 30, 260, 40))
    expect(page_contents(pdf).first).to include("W n")
  end
end
