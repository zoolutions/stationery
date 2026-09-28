# frozen_string_literal: true

RSpec.describe Stationery::Layout::Text do
  it "reports natural and minimum widths" do
    node = text_node("hello wide world")
    font = open_sans_book.resolve(base_style).first

    expect(node.natural_width).to be_within(0.01).of(font.width_of("hello wide world", 10, kerning: true))
    widest = %w[hello wide world].map { |w| font.width_of(w, 10, kerning: true) }.max
    expect(node.min_width).to be_within(0.01).of(widest)
  end

  it "measures a fallback glyph with the fallback font" do
    inter = open_sans_book.resolve(base_style(family: "Inter")).first

    expect(text_node("→→→").min_width).to be_within(0.01).of(inter.width_of("→→→", 10, kerning: true))
  end

  it "splits by lines" do
    head, tail = lines_of(4).split(200, (line_height * 2) + 1)

    expect(head.measure(200)).to be_within(0.001).of(line_height * 2)
    expect(tail.measure(200)).to be_within(0.001).of(line_height * 2)
  end

  describe "orphans and widows" do
    def lines(head, tail) = [head, tail].map { |part| part && (part.measure(200) / line_height).round }

    it "carries more lines over so at least `widows` follow the break" do
      node = lines_of(6, widows: 3)

      expect(lines(*node.split(200, (line_height * 4) + 1))).to eq([3, 3])
    end

    it "moves the paragraph whole when fewer than `orphans` lines would stay" do
      node = lines_of(6, orphans: 3)

      expect(node.split(200, (line_height * 2) + 1)).to eq([nil, node])
    end

    it "moves the paragraph whole when it is shorter than orphans plus widows" do
      node = lines_of(3, orphans: 2, widows: 2)

      expect(node.split(200, (line_height * 2) + 1)).to eq([nil, node])
    end

    it "never moves a paragraph that is first on a fresh page, but still keeps the widows" do
      node = lines_of(6, orphans: 3, widows: 3)

      expect(lines(*node.split(200, (line_height * 2) + 1, fresh: true))).to eq([2, 4])
      expect(lines(*node.split(200, (line_height * 4) + 1, fresh: true))).to eq([3, 3])
    end

    it "splits as before at the defaults" do
      expect(lines(*lines_of(6).split(200, (line_height * 5) + 1))).to eq([5, 1])
    end

    it "keeps the settings on both sides of a split" do
      _head, tail = lines_of(9, widows: 3).split(200, (line_height * 3) + 1)

      expect(lines(*tail.split(200, (line_height * 4) + 1))).to eq([3, 3])
    end

    it "rejects anything but a positive whole number" do
      expect { lines_of(2, orphans: 0) }.to raise_error(ArgumentError, /orphans: must be an Integer of at least 1/)
      expect { lines_of(2, widows: 1.5) }.to raise_error(ArgumentError, /widows:/)
    end
  end
end
