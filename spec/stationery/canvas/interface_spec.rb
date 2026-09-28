# frozen_string_literal: true

RSpec.describe Stationery::Canvas::Interface do
  let(:page) { Stationery::Page.new(size: [200, 100]) }
  let(:calls) { [] }
  let(:canvas) { RecordingCanvas.new(page, calls) }

  def segments(index = 0) = calls[index][1]

  it "is what the PDF canvas answers, but for what is the PDF canvas's own" do
    own = Stationery::Canvas.public_instance_methods - Object.public_instance_methods -
          described_class.public_instance_methods

    expect(own).to contain_exactly(:page, :num, :call, :save, :transform, :clip_to, :draw, :shade_path, :image,
                                   :glyphs)
  end

  it "names every operation a canvas may be asked for" do
    expect(described_class.public_instance_methods).to contain_exactly(
      :page_width, :page_height, :warnings, :outline, :rotate, :clip, :fill_rect, :rounded_rect, :circle, :line,
      :path, :shade, :text, :link, :widget, :anchor, :number_slot, :tagging?, :tag, :tag_runs, :structure,
      :artifact, :debug?, :debug_rect
    )
  end

  it "answers the size of its page" do
    expect([canvas.page_width, canvas.page_height]).to eq([200, 100])
    expect(Stationery::Canvas.new(page, nil).page_height).to eq(100)
  end

  it "brings the shapes down to a path that is drawn" do
    canvas.fill_rect(1, 2, 3, 4, color: "#111111", opacity: 0.5)
    canvas.rounded_rect(0, 0, 10, 10, radius: 2, stroke: "#222222", line_width: 2, dash: [1, 2])
    canvas.circle(5, 5, 2, fill: "#333333")
    canvas.line(0, 0, 9, 9, color: "#444444", width: 3, cap: :round)

    expect(calls.map(&:first)).to eq(%i[draw draw draw draw])
    expect(calls[0]).to eq([:draw, [[:move, 1, 2], [:line, 4, 2], [:line, 4, 6], [:line, 1, 6], :close],
                            { fill: "#111111", opacity: 0.5 }])
    expect(calls[1].last).to eq(fill: nil, stroke: "#222222", line_width: 2, dash: [1, 2], opacity: nil)
    expect(segments(2).count { |kind, *| kind == :curve }).to eq(4)
    expect(calls[3]).to eq([:draw, [[:move, 0, 0], [:line, 9, 9]],
                            { stroke: "#444444", line_width: 3, dash: nil, cap: :round, opacity: nil }])
  end

  it "draws the path a block traces, under its transform" do
    canvas.path(fill: "#000000", even_odd: true, join: :round, transform: [1, 0, 0, 1, 10, 10]) do |path|
      path.move_to(0, 0)
      path.line_to(5, 0)
    end

    expect(calls).to eq([[:draw, [[:move, 10, 10], [:line, 15, 10]],
                          { fill: "#000000", stroke: nil, line_width: 1, cap: :butt, join: :round, dash: nil,
                            even_odd: true, opacity: nil }]])
  end

  it "clips to a rectangle as to any path, and rotates as a transform" do
    canvas.clip(0, 0, 10, 10) { canvas.rotate(90, around: [5, 5]) { canvas.fill_rect(0, 0, 1, 1, color: "#000") } }
    canvas.rotate(0, around: [5, 5]) { calls << [:unrotated] }

    expect(calls.map(&:first)).to eq(%i[clip_to transform draw unrotated])
    expect(calls[1][1].map { it.round(6) }).to eq([0, 1, -1, 0, 10, 0])
  end

  it "paints a shading inside the path a block traces" do
    canvas.shade(:gradient, matrix: [1, 0, 0, 1, 0, 0], even_odd: true) { |path| path.rect(0, 0, 2, 2) }

    expect(calls).to eq([[:shade_path, [[:move, 0, 0], [:line, 2, 0], [:line, 2, 2], [:line, 0, 2], :close],
                          :gradient, { matrix: [1, 0, 0, 1, 0, 0], even_odd: true, opacity: nil }]])
  end

  describe "#text" do
    let(:font) { Stationery::Fonts::Font.new(Stationery::Fonts::Registry.load(font_path("OpenSans-Regular.ttf"))) }

    it "finds the run of glyphs, hands it over and answers its width" do
      width = canvas.text("AV", x: 10, y: 20, font:, size: 10, kerning: true, synthetic_bold: true)
      _, run, x, y, options = calls.first

      expect(run).to be_a(Stationery::Fonts::GlyphRun).and have_attributes(chars: %w[A V])
      expect([x, y, width]).to eq([10, 20, run.width(10)])
      expect(options).to include(font:, size: 10, color: Stationery::Color.parse("#000000"), bold: true,
                                 oblique: false, letter_spacing: 0, rise: 0, opacity: nil)
    end

    it "draws an underline and a strikethrough as rectangles" do
      canvas.text("A", x: 0, y: 20, font:, size: 10, underline: true, strikethrough: true)

      expect(calls.map(&:first)).to eq(%i[glyphs draw draw])
    end

    it "draws nothing for no text" do
      expect(canvas.text("", x: 0, y: 0, font:, size: 10)).to eq(0)
      expect(calls).to be_empty
    end
  end

  describe "what only some outputs have a use for" do
    let(:element) { Stationery::Tagging::Element.new(:P) }

    it "runs the blocks of tagging and artifacts, and marks nothing" do
      seen = []
      canvas.tag(element, bbox: [0, 0, 1, 1]) { seen << :tag }
      canvas.tag(nil) { seen << :untagged }
      canvas.structure(element) { seen << :structure }
      canvas.artifact(type: :pagination, subtype: :header) { seen << :artifact }
      canvas.tag_runs(element) { |mark| mark.call(element) { seen << :run } }

      expect(seen).to eq(%i[tag untagged structure artifact run])
      expect(canvas.tagging?).to be(false)
      expect(element).not_to be_attached
      expect(calls).to be_empty
    end

    it "takes links and form fields and does nothing" do
      field = Stationery::Forms::Field.new(:text, "name")

      expect(canvas.link(0, 0, 10, 10, "https://example.com", tag: element)).to be_nil
      expect(canvas.widget(field, 0, 0, 10, 10)).to be_nil
      expect(page.annotations).to be_empty
    end

    it "records anchors and page-number slots on the page, for Structure" do
      canvas.anchor(:top, 10)
      RecordingCanvas.new(page, calls, template: true).anchor("header", 0)
      canvas.number_slot("top", x: 1, baseline: 2, width: 3, style: :style)

      expect(page.anchors).to eq([["top", 90]])
      expect(page.template_anchors).to eq([["header", 100]])
      expect(page.slots).to eq([Stationery::Page::Slot.new("top", 1, 2, 3, :style, nil, nil)])
    end
  end

  describe "#debug_rect" do
    it "outlines the rectangles of the kinds asked for" do
      RecordingCanvas.new(page, calls, debug: [:box]).then do |debugging|
        debugging.debug_rect(0, 0, 10, 10, :box)
        debugging.debug_rect(0, 0, 10, 10, :cell)

        expect(debugging).to be_debug
      end

      expect(calls.size).to eq(1)
      expect(canvas).not_to be_debug
    end
  end
end
