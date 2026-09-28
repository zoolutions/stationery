# frozen_string_literal: true

RSpec.describe Stationery::Raster::Canvases do
  let(:page) { Stationery::Page.new(size: [100, 100]) }
  let(:warnings) { Stationery::Warnings.new }
  let(:canvases) { described_class.new(warnings:) }

  def square(canvas, color) = canvas.fill_rect(0, 0, 10, 10, color:)

  it "records what a page is asked to draw, with the transform and clip it was drawn under" do
    canvas = canvases.body(page)
    canvas.rotate(90, around: [50, 50]) do
      canvas.clip(0, 0, 20, 20) { square(canvas, "#FF0000") }
    end
    call = canvases.list(page).first

    expect(call).to be_a(Stationery::Raster::Canvas::Draw).and have_attributes(fill: Stationery::Color.parse("#FF0000"))
    expect(call.matrix.map { |v| v.round(6) }).to eq([0, 1, -1, 0, 100, 0])
    expect(call.clip.paths.first.each_segment.first).to eq([:move, 0, 0])
    expect(call.clip.matrix).to eq(call.matrix)
  end

  it "puts what a background template paints under the page, and a foreground one over it" do
    square(canvases.body(page), "#000001")
    canvases.template(page, :foreground) { |canvas| square(canvas, "#000002") }
    canvases.template(page, :background) { |canvas| square(canvas, "#000003") }
    square(canvases.over(page), "#000004")

    expect(canvases.list(page).map { |call| call.fill.components.last * 255 }.map(&:round)).to eq([3, 1, 2, 4])
  end

  it "keeps the list of every page until it is let go of" do
    other = Stationery::Page.new(size: [100, 100])
    square(canvases.body(page), "#000000")
    square(canvases.body(other), "#000000")

    expect(canvases.release(page).size).to eq(1)
    expect(canvases.list(page)).to be_empty
    expect(canvases.list(other).size).to eq(1)
  end

  it "draws a JPEG as a crossed box, and says so" do
    jpeg = Stationery::Images::JPEG.new(File.binread(File.join(RenderDigests::ROOT, "spec/fixtures/images/rgb.jpg")))
    canvases.body(page).image(jpeg, x: 10, y: 10, width: 40, height: 30)
    surface = Stationery::Raster::Surface.new(100, 100, 3)
    Stationery::Raster::Painter.new(surface, dpi: 72, antialias: true).paint(canvases.list(page))

    expect(warnings.map(&:message)).to eq([%(image "JPEG #{jpeg.width}x#{jpeg.height}" skipped: a JPEG is not ) \
                                           "decoded for a picture yet; drawn as a crossed box"])
    expect(surface.data.byteslice(((20 * 100) + 12) * 3, 3).bytes).to eq([229, 231, 235])
  end

  it "paints through the rules of a monochrome render" do
    rules = Stationery::Monochrome::Rules.new(Stationery::Monochrome.settings(snap: true), warnings)
    canvas = described_class.new(warnings:, monochrome: rules).body(page)

    expect(canvas).to be_a(Stationery::Monochrome::Painting)
    expect(rules.page_number(page)).to eq(1)
  end
end
