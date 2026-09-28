# frozen_string_literal: true

RSpec.describe Stationery::Document do
  # Bitmap resolution: the images(max_ppi:, downscale:) class-level defaults.
  let(:png) { PngFactory.build(width: 620, height: 2, color_type: 2, rows: Array.new(2) { [0] * 1860 }) }
  let(:path) do
    file = Tempfile.new(["photo", ".png"])
    file.binmode
    file.write(png)
    file.close
    file.path
  end

  it "warns at the default 300 ppi limit and inherits a class-level images setting" do
    file = path
    doc = SpecDocument.build { image file, width: 72 }
    doc.to_pdf
    expect(doc.warnings.map(&:class)).to eq([Stationery::Warnings::OversizedImage])

    quiet = Class.new(SpecDocument) { images max_ppi: nil }
    doc = Class.new(quiet) { define_method(:view_template) { image file, width: 72 } }.new
    doc.to_pdf
    expect(doc.warnings).to be_empty
  end

  it "downscales every PNG when the document says so, and a call can opt out" do
    scaled = Class.new(SpecDocument) { images downscale: true }
    file = path
    pdf = Class.new(scaled) { define_method(:view_template) { image file, width: 72 } }.new.to_pdf
    expect(pdf).to include("/Width 300")

    kept = Class.new(scaled) { define_method(:view_template) { image file, width: 72, downscale: false } }.new
    expect(kept.to_pdf).to include("/Width 620")
    expect(kept.warnings.size).to eq(1)
  end

  it "raises on strict documents like any other warning" do
    checked = Class.new(SpecDocument) { strict true }
    file = path
    doc = Class.new(checked) { define_method(:view_template) { image file, width: 72 } }.new

    expect { doc.to_pdf }.to raise_error(Stationery::WarningsError, /620 ppi/)
  end

  it "reports images drawn by page templates too" do
    file = path
    doc = Class.new(SpecDocument) do
      page_template { |_page| box(at: [0, 0]) { image file, width: 72 } }
      def view_template = text("x")
    end.new
    doc.to_pdf

    expect(doc.warnings.map(&:class)).to eq([Stationery::Warnings::OversizedImage])
  end
end
