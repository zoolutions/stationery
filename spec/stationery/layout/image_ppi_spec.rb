# frozen_string_literal: true

require "stringio"

RSpec.describe Stationery::Layout::Image do
  # Resolution: the oversized-image warning and PNG downscaling.
  # A 620 px wide RGB PNG, so that drawn 72 pt wide it sits at 620 ppi.
  let(:png) { PngFactory.build(width: 620, height: 2, color_type: 2, rows: Array.new(2) { [0] * 1860 }) }
  let(:path) do
    file = Tempfile.new(["photo", ".png"])
    file.binmode
    file.write(png)
    file.close
    file.path
  end

  def tidy(value) = value.round(6)

  def render(node)
    resources = Stationery::Resources.new
    paginator = Stationery::Layout::Paginator.new(resources:, page: { size: [300, 200], margin: 20 })
    pages = paginator.paginate(Stationery::Layout::Flow.new([node]))
    [Stationery::PDF::Assembler.new(pages:, resources:).render, paginator.warnings.to_a]
  end

  it "warns once when an image is drawn at more than twice the ppi limit, naming the file" do
    _pdf, warnings = render(described_class.new(path, width: 72))

    expect(warnings.map(&:class)).to eq([Stationery::Warnings::OversizedImage])
    expect(warnings.first.message)
      .to eq(%(image "#{File.basename(path)}" 620px wide is drawn at 620 ppi (limit 300); resize it before embedding))
  end

  it "stays quiet at or under twice the limit, and with max_ppi: nil" do
    expect(render(described_class.new(path, width: 72, max_ppi: 300)).last).not_to be_empty
    expect(render(described_class.new(path, width: 72, max_ppi: 400)).last).to be_empty
    expect(render(described_class.new(path, width: 144)).last).to be_empty
    expect(render(described_class.new(path, width: 72, max_ppi: nil)).last).to be_empty
  end

  it "calls an IO an inline image" do
    _pdf, warnings = render(described_class.new(StringIO.new(png), width: 72))

    expect(warnings.first.message).to start_with('image "inline image" 620px wide')
  end

  it "reports the same image and size once, and each drawn size on its own" do
    flow = Stationery::Layout::Flow.new([described_class.new(path, width: 72), described_class.new(path, width: 72),
                                         described_class.new(path, width: 60)])
    _pdf, warnings = render(flow)

    expect(warnings.map(&:ppi)).to eq([620, 744])
  end

  it "measures a cover-cropped image by the size it is actually drawn at" do
    _pdf, warnings = render(described_class.new(path, width: 72, height: 72, fit: :cover))

    # 620×2 covering 72×72 scales by 36: drawn 22320 pt wide, 2 ppi
    expect(warnings).to be_empty
  end

  it "downscales a PNG to the limit at its drawn size when asked, and leaves the layout alone" do
    node = described_class.new(path, width: 72, downscale: true)
    pdf, warnings = render(node)

    expect(warnings).to be_empty
    expect(node.size(300)).to eq([72, tidy(72 * 2 / 620.0)])
    expect(pdf).to include("/Width 300")
    expect(pdf).not_to include("/Width 620")
  end

  it "never touches a JPEG" do
    node = described_class.new(image_path("rgb.jpg"), width: 72, downscale: true)
    plain, = render(described_class.new(image_path("rgb.jpg"), width: 72))

    expect(render(node).first).to eq(plain)
  end
end
