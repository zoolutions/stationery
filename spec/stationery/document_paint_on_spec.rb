# frozen_string_literal: true

# The seam another output paints through: the layout `to_pdf` runs, painted
# on canvases that are not the PDF canvas (RecordingCanvas).
RSpec.describe Stationery::Document, "#paint_on" do
  let(:canvases) { RecordingCanvases.new }

  def untouched(pages)
    pages.all? { |page| page.content.empty? && page.annotations.empty? && page.resource_names.empty? && !page.sealed? }
  end

  it "covers every example" do
    expect(Dir[File.join(RenderDigests::ROOT, "examples/*.rb")].size).to eq(RenderDigests::EXAMPLES.size)
  end

  Dir[File.join(RenderDigests::ROOT, "examples/*.rb")].map { |file| File.basename(file, ".rb") }.sort.each do |name|
    it "paints examples/#{name}.rb on canvases of another output, as many pages as the PDF has" do
      pages = RenderDigests.example(name).paint_on(canvases)

      expect(pages.size).to eq(RenderDigests.example(name).to_pdf.scan(%r{/Type\s*/Page(?![s\w])}).size)
      expect(canvases.calls.keys).to eq(pages)
      expect(canvases.all.map(&:first)).to include(:glyphs)
      expect(untouched(pages)).to be(true)
    end

    it "paints examples/#{name}.rb with the rectangles of its layout" do
      canvases = RecordingCanvases.new(debug: true)

      expect(untouched(RenderDigests.example(name).paint_on(canvases))).to be(true)
      expect(canvases.all.size).to be > self.canvases.tap { RenderDigests.example(name).paint_on(it) }.all.size
    end
  end

  %i[StationeryTable StationeryText StationeryHyphenated StationeryPhotos StationeryWebp StationeryHtml
     StationeryAccessible StationeryIncremental StationeryShaped].each do |name|
    it "paints the benchmark's #{name} on canvases of another output" do
      require File.join(RenderDigests::ROOT, "benchmark/features")
      pages = Bench.const_get(name).new.paint_on(canvases)

      expect(canvases.calls.keys).to eq(pages)
      expect(canvases.texts.join).to include("e")
      expect(untouched(pages)).to be(true)
    end
  end

  it "needs no PDF to be written: no resources, no assembler" do
    allow(Stationery::Resources).to receive(:new).and_call_original
    allow(Stationery::PDF::Assembler).to receive(:new).and_call_original
    allow(Stationery::Canvas).to receive(:new).and_call_original

    RenderDigests.example("report").paint_on(canvases)

    expect(Stationery::Resources).not_to have_received(:new)
    expect(Stationery::PDF::Assembler).not_to have_received(:new)
    expect(Stationery::Canvas).not_to have_received(:new)
  end

  it "hands over paths as segments in top-left space, and colours and widths as values" do
    document = SpecDocument.build do
      box(background: "#FF0000", border: { width: 2, color: "#0000FF" }, width: 50, height: 30) { nil }
    end
    document.paint_on(canvases)
    fill, stroke = canvases.all.select { |name, *| name == :draw }

    expect(fill).to eq([:draw, [[:move, 20, 20], [:line, 70, 20], [:line, 70, 50], [:line, 20, 50], :close],
                        { fill: "#FF0000", stroke: nil, line_width: 1, dash: nil, opacity: nil }])
    expect(stroke.last).to include(stroke: "#0000FF", line_width: 2)
  end

  it "hands over text as a run of glyph ids with its font, size and colour" do
    SpecDocument.build { text "Hi", size: 12, color: "#112233" }.paint_on(canvases)
    _, run, x, y, options = canvases.all.find { |name, *| name == :glyphs }

    expect(run.gids).to eq("Hi".chars.map { |char| run.font.ttf.glyph_id(char.ord) })
    expect([x, y]).to match([20, be_between(20, 40)])
    expect(options).to include(size: 12, color: Stationery::Color.parse("#112233"), bold: false, oblique: false)
  end

  it "hands over an image as the object that holds its pixels" do
    png = File.join(RenderDigests::ROOT, "examples/assets/sea.png")
    SpecDocument.build { image png, width: 40 }.paint_on(canvases)
    _, image, options = canvases.all.find { |name, *| name == :image }

    expect(image).to be_a(Stationery::Images::PNG).and have_attributes(width: be_positive, height: be_positive)
    expect(options).to include(x: 20, y: 20, width: 40)
  end

  it "draws the page numbers of a table of contents, which Structure fills in" do
    document = SpecDocument.build do
      table_of_contents
      page_break
      bookmark "Alpha"
      text "One"
      page_break
      bookmark "Beta"
      text "Two"
    end
    pages = document.paint_on(canvases)

    expect(pages.size).to eq(3)
    expect(canvases.texts).to eq(%w[Alpha Beta 2 3 One Two])
    expect(canvases.calls[pages.first].last(2).map(&:first)).to eq(%i[glyphs glyphs])
  end

  it "says which layer a page template paints on, and yields the bookmarks that were painted" do
    klass = Class.new(SpecDocument) do
      page_template(layer: :background) { |page| box(at: [0, 0]) { text "under #{page.number}" } }
      footer { |page| text "page #{page.number} of #{page.count}" }
      define_method(:view_template) do
        bookmark "Start"
        text "body"
      end
    end
    bookmarks = nil
    klass.new.paint_on(canvases) { bookmarks = it }

    expect(canvases.all.select { |name, *| name == :layer }).to eq([%i[layer foreground], %i[layer background]])
    expect(canvases.texts).to eq(["body", "page 1 of 1", "under 1"])
    expect(bookmarks.map(&:title)).to eq(["Start"])
  end

  it "collects the warnings of the render and hands each page over as it is painted" do
    document = SpecDocument.build { box(height: 400, break_inside: :avoid) { text "tall" } }
    seen = []
    pages = document.paint_on(canvases, each_page: ->(page) { seen << page })

    expect(seen).to eq(pages)
    expect(document.warnings.map(&:class)).to eq([Stationery::Layout::Overflow])
  end
end
