# frozen_string_literal: true

RSpec.describe Stationery::Raster::Scanner do
  def square(x0, y0, x1, y1) = [x0, y0, x1, y0, x1, y1, x0, y1]

  def area(spans) = spans.to_a.sum { |_, x0, x1, coverage| (x1 - x0) * coverage }

  context "without anti-aliasing (one bit)" do
    let(:scanner) { described_class.new(20, 10, antialias: false) }

    it "takes a pixel whose centre is inside" do
      spans = scanner.spans([square(2, 1, 6, 3)])

      expect(spans.to_a).to eq([[1, 2, 6, 1.0], [2, 2, 6, 1.0]])
    end

    it "leaves a pixel whose centre is outside, however much of it is covered" do
      spans = scanner.spans([square(2.6, 1.6, 5.4, 2.6)])

      expect(spans.to_a).to eq([[2, 3, 5, 1.0]])
    end

    it "fills a hole traced the same way round under nonzero, and leaves it under even-odd" do
      shapes = [square(0, 0, 10, 10), square(3, 3, 7, 7)]

      expect(area(scanner.spans(shapes))).to eq(100)
      expect(area(scanner.spans(shapes, even_odd: true))).to eq(84)
    end

    it "leaves a hole traced the other way round under nonzero" do
      hole = [3, 3, 3, 7, 7, 7, 7, 3]

      expect(area(scanner.spans([square(0, 0, 10, 10), hole]))).to eq(84)
    end

    it "keeps to the surface" do
      spans = scanner.spans([square(-5, -5, 30, 30)])

      expect(spans.to_a.map(&:first)).to eq((0...10).to_a)
      expect(spans.to_a.map { |_, x0, x1, _| [x0, x1] }.uniq).to eq([[0, 20]])
    end
  end

  context "with anti-aliasing" do
    let(:scanner) { described_class.new(20, 10, antialias: true) }

    it "covers a pixel an edge crosses by the share of it inside" do
      spans = scanner.spans([square(2.5, 1, 4, 2)])

      expect(spans.to_a).to eq([[1, 2, 3, 0.5], [1, 3, 4, 1.0]])
    end

    it "covers as much as the shape's area" do
      triangle = [1, 1, 9, 2, 3, 8.5]
      expected = ((1 * (2 - 8.5)) + (9 * (8.5 - 1)) + (3 * (1 - 2))).abs / 2.0

      expect(area(scanner.spans([triangle]))).to be_within(0.3).of(expected)
    end
  end

  describe Stationery::Raster::Spans do
    it "intersects with another, multiplying the coverage" do
      scanner = Stationery::Raster::Scanner.new(20, 10, antialias: true)
      a = scanner.spans([square(0, 0, 10, 2)])
      b = scanner.spans([square(4.5, 1, 20, 5)])

      expect(a.intersect(b).to_a).to eq([[1, 4, 5, 0.5], [1, 5, 10, 1.0]])
    end
  end
end
