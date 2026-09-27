# frozen_string_literal: true

RSpec.describe Stationery::Layout::Stack do
  def base(height) = flow(Stationery::Layout::Box.new(flow, height:, background: "#EEEEEE"))
  def card(**) = Stationery::Layout::Box.new(flow, background: "#000000", **)
  def layer(box, **) = Stationery::Layout::Layer.new(box, **)

  # [x, y, w, h] of every filled rectangle on the first page, in top-left coordinates.
  def rects(pdf)
    page_contents(pdf).first.scan(/([-\d.]+) ([-\d.]+) ([-\d.]+) ([-\d.]+) re/).map do |x, y, w, h|
      [x.to_f, 200 - y.to_f - h.to_f, w.to_f, h.to_f]
    end
  end

  it "is as tall as its base and takes its widths from it" do
    stack = described_class.new(base(50), [layer(card(height: 10), top: 0, left: 0)])

    expect(stack.measure(260)).to eq(50)
    expect(stack.natural_width).to eq(0)
    expect(stack.fixed_width(260)).to be_nil
    expect(stack).not_to be_splittable
  end

  it "paints layers relative to its rectangle from the top-left by default" do
    pdf, = render_layout(described_class.new(base(50), [layer(card(width: 30, height: 10))]))

    expect(rects(pdf)).to eq([[20, 20, 260, 50], [20, 20, 30, 10]])
  end

  it "places a layer by its insets in points, negative ones overhanging" do
    layers = [layer(card(width: 30, height: 10), top: 5, left: 8),
              layer(card(width: 30, height: 10), bottom: -6, right: -4)]
    pdf, = render_layout(described_class.new(base(50), layers))

    expect(rects(pdf).drop(1)).to eq([[28, 25, 30, 10], [254, 66, 30, 10]])
  end

  it "resolves fractions against its own width and height" do
    layers = [layer(card(height: 10), left: 0.5, top: 1/5r, width: 0.25),
              layer(card(width: 26), right: 0, bottom: 0, height: 0.2)]
    pdf, = render_layout(described_class.new(base(50), layers))

    expect(rects(pdf).drop(1)).to eq([[150, 30, 65, 10], [254, 60, 26, 10]])
  end

  it "gives a layer its content's natural width when none is set, at most its own" do
    long = text_node("a long line of text that runs on and on and on and on and on")
    wide = Stationery::Layout::Box.new(flow(long), height: 10)
    layers = [layer(card(width: :auto, padding: [0, 10], height: 10)), layer(wide, top: 20)]
    pdf, = render_layout(described_class.new(base(50), layers))
    rect = rects(pdf)

    expect(rect[1]).to eq([20, 20, 20, 10])
    expect(rect.size).to eq(2)
  end

  it "moves whole to the next page and warns when taller than a page" do
    stack = described_class.new(base(120), [layer(card(width: 10, height: 10))])
    pdf, paginator = render_layout(flow(spacer(100), stack))

    expect(page_count(pdf)).to eq(2)
    expect(paginator.warnings).to be_empty
    expect(rects(pdf).map(&:first)).to all(eq(20))

    _, tall = render_layout(described_class.new(base(300), []))
    expect(tall.warnings.map(&:class)).to eq([Stationery::Layout::Overflow])
  end
end
