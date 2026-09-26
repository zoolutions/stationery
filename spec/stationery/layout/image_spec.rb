# frozen_string_literal: true

RSpec.describe Stationery::Layout::Image do
  def image(**) = described_class.new(image_path("rgb.jpg"), **)

  it "preserves the aspect ratio from one dimension or a fit box" do
    expect(image(width: 40).size(300)).to eq([40, 30])
    expect(image(height: 30).size(300)).to eq([40, 30])
    expect(image(fit: [100, 30]).size(300)).to eq([40, 30])
    expect(image(width: 10, height: 50).size(300)).to eq([10, 50])
  end

  it "defaults to its pixel size in points, capped at the available width" do
    expect(image.size(300)).to eq([4, 3])
    expect(described_class.new(image_path("rgb.jpg"), width: 400).size(200)).to eq([200, 150])
  end
end
