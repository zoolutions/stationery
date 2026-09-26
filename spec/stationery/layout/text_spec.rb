# frozen_string_literal: true

RSpec.describe Stationery::Layout::Text do
  it "reports natural and minimum widths" do
    node = text_node("hello wide world")
    font = open_sans_book.resolve(base_style).first

    expect(node.natural_width).to be_within(0.01).of(font.width_of("hello wide world", 10))
    expect(node.min_width).to be_within(0.01).of(%w[hello wide world].map { |w| font.width_of(w, 10) }.max)
  end

  it "splits by lines" do
    head, tail = lines_of(4).split(200, (line_height * 2) + 1)

    expect(head.measure(200)).to be_within(0.001).of(line_height * 2)
    expect(tail.measure(200)).to be_within(0.001).of(line_height * 2)
  end
end
