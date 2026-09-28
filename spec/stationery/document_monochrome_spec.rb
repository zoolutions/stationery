# frozen_string_literal: true

RSpec.describe Stationery::Document do
  def label_body
    proc do
      text "SKU 4711-A", size: 26, weight: :bold
      text "Hex bolt M8 × 40, zinc plated", size: 12, style: :italic, color: "#888888"
      spacer 5
      rule height: 0.5, color: "#DDDDDD"
      spacer 5
      text "Bin C-07 · 250 pcs", size: 12
      spacer 4
      box(background: "#F3F4F6", padding: 5, radius: 3) { text "Reorder below 50", size: 10, color: "#6B7280" }
    end
  end

  let(:plain) do
    body = label_body
    Class.new(SpecDocument) do
      page size: [mm(100), mm(60)], margin: mm(4)
      define_method(:view_template, &body)
    end
  end
  let(:label) { Class.new(plain) { monochrome dpi: 203 } }

  def not_monochrome(document) = document.warnings.grep(Stationery::Warnings::NotMonochrome)
  def colors_of(pdf) = inspect_pdf(pdf).colors

  def at(time = Time.utc(2026, 1, 1, 12))
    allow(Time).to receive(:now).and_return(time)
    yield
  end

  describe "without monochrome" do
    it "writes what it wrote: the same bytes, and no warning" do
      at do
        pdf = plain.new.to_pdf

        expect(plain.new.to_pdf(monochrome: false)).to eq(pdf)
        expect(label.new.to_pdf(monochrome: false)).to eq(pdf)
        expect(Class.new(label) { monochrome false }.new.to_pdf).to eq(pdf)
      end
    end
  end

  describe ".monochrome" do
    it "reports every colour that is not black or white, once per colour, kind and page" do
      document = label.new
      document.to_pdf

      expect(not_monochrome(document).map(&:to_h)).to contain_exactly(
        { color: "#888888", kind: :text, page: 1 }, { color: "#DDDDDD", kind: :rule, page: 1 },
        { color: "#F3F4F6", kind: :background, page: 1 }, { color: "#6B7280", kind: :text, page: 1 }
      )
      expect(not_monochrome(document).first.message).to eq("text in #888888 on page 1 is not black or white")
    end

    it "is what strict catches" do
      expect { Class.new(label) { strict }.new.to_pdf }.to raise_error(Stationery::WarningsError, /#888888/)
    end

    it "reports a colour on every page it is on, and text drawn in black at an opacity" do
      document = SpecDocument.build do
        3.times { text "grey", color: "#999999" }
        page_break
        text "grey", color: "#999999"
        text "faint", opacity: 0.5
      end
      document.to_pdf(monochrome: true)

      expect(not_monochrome(document).map(&:to_h)).to eq(
        [{ color: "#999999", kind: :text, page: 1 }, { color: "#999999", kind: :text, page: 2 },
         { color: "#000000 at opacity 0.5", kind: :text, page: 2 }]
      )
    end

    it "is inherited, and laid over per render" do
      expect(Class.new(label).config[:monochrome].dpi).to eq(203)
      expect(Class.new(label) { monochrome snap: true }.config[:monochrome].to_h).to include(dpi: 203, snap: true)

      document = plain.new
      document.to_pdf(monochrome: { dpi: 300 })

      expect(not_monochrome(document).size).to eq(4)
    end

    it "sees what a canvas block and an SVG paint" do
      document = SpecDocument.build do
        canvas(height: 20) { |c, rect| c.line(rect.x, rect.y + 5, rect.right, rect.y + 5, color: "#FF0000") }
        svg '<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10"><rect width="10" height="10" ' \
            'fill="#00FF00"/></svg>'
      end
      document.to_pdf(monochrome: true)

      expect(not_monochrome(document).map { [it.color, it.kind] })
        .to contain_exactly(["#FF0000", :border], ["#00FF00", :background])
    end

    it "reports a gradient by its stops, and a line a transform makes thinner than a dot" do
      document = SpecDocument.build do
        svg '<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10"><linearGradient id="g">' \
            '<stop offset="0" stop-color="#000"/><stop offset="1" stop-color="#3366CC"/></linearGradient>' \
            '<rect width="10" height="10" fill="url(#g)"/></svg>'
        canvas(height: 20) do |c, rect|
          c.transform([0.5, 0, 0, 0.5, rect.x, rect.y]) { c.line(0, 0, 100, 0, color: "#000000", width: 0.6) }
        end
      end
      document.to_pdf(monochrome: true)

      expect(document.warnings.map(&:class).uniq)
        .to contain_exactly(Stationery::Warnings::NotMonochrome, Stationery::Warnings::ThinLine)
      expect(not_monochrome(document).map(&:to_h)).to eq([{ color: "#3366CC", kind: :gradient, page: 1 }])
      expect(document.warnings.grep(Stationery::Warnings::ThinLine).map(&:width)).to eq([0.3])
    end
  end

  describe "snap: true" do
    let(:snapped) { Class.new(label) { monochrome snap: true } }

    it "paints text, rules and strokes black and drops light fills, without a warning" do
      document = snapped.new
      pdf = document.to_pdf

      expect(document.warnings.to_a).to be_empty
      expect(colors_of(pdf)).to eq(["#000000"])
      expect(inspect_pdf(pdf).text).to include("Reorder below 50")
    end

    it "paints a dark fill black, keeps white white and an opacity away" do
      pdf = SpecDocument.build do
        box(background: "#333333", padding: 4) { text "white on dark", color: "#FFFFFF" }
        box(background: "#000000", opacity: 0.3) { text "faint box" }
      end.to_pdf(monochrome: { snap: true })

      expect(colors_of(pdf)).to eq(["#000000", "#FFFFFF"])
      expect(page_contents(pdf).join).not_to include(" gs")
    end

    it "lets a threshold decide which fills are dark" do
      document = SpecDocument.build { box(background: "#999999") { text "x", color: "#FFFFFF" } }

      expect(colors_of(document.to_pdf(monochrome: { snap: true }))).to eq(["#FFFFFF"])
      expect(colors_of(document.to_pdf(monochrome: { snap: true, threshold: 0.7 }))).to eq(["#000000", "#FFFFFF"])
    end
  end

  describe "line widths and the dot grid" do
    let(:hairlines) do
      SpecDocument.build do
        rule height: 0.2
        box(border: { width: 0.1, color: "#000000" }, padding: 2) { text "boxed" }
      end
    end

    it "reports a line thinner than a dot, and leaves it" do
      hairlines.to_pdf(monochrome: true)
      warnings = hairlines.warnings.grep(Stationery::Warnings::ThinLine)

      expect(warnings.map { [it.kind, it.width] }).to contain_exactly([:rule, 0.2], [:border, 0.1])
      expect(warnings.first.message).to include("thinner than a dot at 203 dpi (0.355 pt)")
    end

    it "widens it to a dot with snap: true" do
      content = page_contents(hairlines.to_pdf(monochrome: { snap: true })).join

      expect(hairlines.warnings.to_a).to be_empty
      expect(content).to include("0.3547 w")
      expect(content).to include(" 0.3547 re")
    end

    it "puts a rule on whole dots, as wide wherever it lands" do
      document = SpecDocument.build do
        spacer 0.3
        rule height: 1
        spacer 7.77
        rule height: 1
      end
      content = page_contents(document.to_pdf(monochrome: { dpi: 72 })).join
      rects = content.scan(/^(\S+) (\S+) (\S+) (\S+) re$/).map { |values| values.map(&:to_f) }

      expect(rects.size).to eq(2)
      expect(rects.flatten).to all(satisfy { |value| value == value.round })
      expect(rects.map(&:last)).to eq([1, 1])
    end
  end

  describe "images" do
    let(:photo) do
      rows = Array.new(8) { |y| Array.new(8) { |x| [x * 32, y * 32, 128] }.flatten }
      PngFactory.build(width: 8, height: 8, color_type: 2, rows:)
    end

    def image_dictionary(pdf)
      objects = reader_for(pdf).objects
      streams = objects.values.map { objects.deref(it) }.grep(PDF::Reader::Stream)
      streams.find { it.hash[:Subtype] == :Image }.hash
    end

    it "resamples a bitmap to the dots it covers and dithers it to one bit" do
      source = photo
      pdf = SpecDocument.build { image StringIO.new(source), width: 72, height: 36 }.to_pdf(monochrome: { dpi: 100 })

      expect(image_dictionary(pdf)).to include(Width: 100, Height: 50, BitsPerComponent: 1, ColorSpace: :DeviceGray)
    end

    it "dithers as asked" do
      source = photo
      document = SpecDocument.build { image StringIO.new(source), width: 36 }
      renders = %i[floyd_steinberg ordered threshold].map { document.to_pdf(monochrome: { dither: it }) }

      expect(renders.uniq.size).to eq(3)
      expect(document.warnings.to_a).to be_empty
    end

    it "reports a JPEG, which it does not decode" do
      path = image_path("rgb.jpg")
      document = SpecDocument.build { image path, width: 20 }
      document.to_pdf(monochrome: true)

      expect(not_monochrome(document).map(&:to_h)).to eq([{ color: "JPEG 4x3", kind: :image, page: 1 }])
    end
  end
end
