# frozen_string_literal: true

RSpec.describe Stationery::Layout::Image do
  def image(**) = described_class.new(image_path("rgb.jpg"), **)

  # Paints the node at the top-left of a 300×200 page with a 20pt margin and
  # returns the first page's content stream.
  def paint(node) = page_contents(render_layout(flow(node)).first).first

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

  it "paints a plain image as one placed XObject" do
    expect(paint(image(width: 40))).to eq("q\n40 0 0 30 20 150 cm\n/Im1 Do\nQ\n")
  end

  describe "fit: :cover" do
    it "takes the box size and needs both dimensions" do
      expect(image(width: 10, height: 20, fit: :cover).size(300)).to eq([10, 20])
      expect(image(width: 10, height: 20, fit: :cover).measure(300)).to eq(20)
      expect { image(width: 10, fit: :cover) }
        .to raise_error(ArgumentError, "fit: :cover needs width: and height:")
      expect { image(height: 10, fit: :cover) }
        .to raise_error(ArgumentError, "fit: :cover needs width: and height:")
    end

    it "scales a landscape image up to fill a portrait box, centred and clipped" do
      ops = paint(image(width: 10, height: 20, fit: :cover))

      # 4×3 covering 10×20: scale 20/3, so 26.67 wide, 8.33 past each side
      expect(ops).to eq("q\n20 160 10 20 re\nW n\nq\n26.6667 0 0 20 11.6667 160 cm\n/Im1 Do\nQ\nQ\n")
    end

    it "scales to fill a wide box, cropping top and bottom" do
      ops = paint(image(width: 40, height: 10, fit: :cover))

      # 4×3 covering 40×10: scale 10, so 30 tall, 10 past top and bottom
      expect(ops).to eq("q\n20 170 40 10 re\nW n\nq\n40 0 0 30 20 160 cm\n/Im1 Do\nQ\nQ\n")
    end

    it "scales down to the available width like any image" do
      node = described_class.new(image_path("rgb.jpg"), width: 400, height: 100, fit: :cover)

      expect(node.size(200)).to eq([200, 50])
    end
  end

  describe "radius:" do
    it "clips the image to a rounded rectangle" do
      ops = paint(image(width: 40, radius: 4))

      expect(ops).to start_with("q\n24 180 m\n56 180 l\n")
      expect(ops).to include(" c\n").and include("W n\nq\n40 0 0 30 20 150 cm\n/Im1 Do\nQ\nQ\n")
    end

    it "clips a cover-fitted image with the same rounded rectangle" do
      ops = paint(image(width: 40, height: 10, fit: :cover, radius: 2))

      expect(ops.scan(" c\n").size).to eq(4)
      expect(ops).to include("W n\nq\n40 0 0 30 20 160 cm\n/Im1 Do\nQ\nQ\n")
    end
  end

  describe "rotate:" do
    it "turns the painted image around the centre of its layout rectangle" do
      node = image(width: 40, rotate: 90)
      ops = paint(node)

      # centre of the 40×30 rectangle at (20, 20) is (40, 35): rotate(90, around: [40, 35])
      expect(ops).to eq("q\n0 -1 1 0 -125 205 cm\nq\n40 0 0 30 20 150 cm\n/Im1 Do\nQ\nQ\n")
      expect(node.size(300)).to eq([40, 30])
      expect(node.measure(300)).to eq(30)
    end

    it "rotates before clipping so the clip turns with the image" do
      ops = paint(image(width: 40, height: 10, fit: :cover, radius: 2, rotate: -3))

      expect(ops).to match(%r{\Aq\n[^\n]+ cm\nq\n[^W]+W n\nq\n40 0 0 30 20 160 cm\n/Im1 Do\nQ\nQ\nQ\n\z})
    end

    it "keeps the Figure bounding box on the layout rectangle" do
      doc = Class.new(SpecDocument) do
        tagged
        metadata lang: "en"
      end
      path = image_path("rgb.jpg")
      pdf = doc.build { image path, width: 40, rotate: 45, alt: "photo" }.to_pdf

      expect(pdf).to include("/BBox [20 150 60 180]")
    end
  end
end
