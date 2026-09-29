# frozen_string_literal: true

require "tmpdir"

RSpec.describe Stationery::Document, "#to_zpl" do
  # The shelf label of #144: grey text, a light rule and a light box, which
  # monochrome reports and dithers.
  let(:shelf_label) do
    Class.new(SpecDocument) do
      page size: [mm(100), mm(60)], margin: mm(4)
      default_text size: 11

      define_method(:view_template) do
        text "SKU 4711-A", size: 26, weight: :bold
        text "Hex bolt M8 × 40, zinc plated", size: 12, style: :italic, color: "#888888"
        spacer 5
        rule height: 0.5, color: "#DDDDDD"
        spacer 5
        text "Bin C-07 · 250 pcs", size: 12
        spacer 4
        box(background: "#F3F4F6", padding: 5, radius: 3) { text "Reorder below 50", size: 10, color: "#6B7280" }
      end
    end.new
  end

  let(:shipping_label) do
    Class.new(SpecDocument) do
      page size: "4in x 6in", margin: mm(4)

      define_method(:view_template) do
        text "SHIP TO", size: 9, weight: :bold
        text "Ada Example\n12 Sample Street\n12345 Testville", size: 16
        spacer 12
        rule height: 2
        spacer 12
        box(border: { width: 3 }, padding: 8) { text "PRIORITY", size: 40, weight: :bold, align: :center }
      end
    end.new
  end

  it "writes one label per page: ^XA, the size in dots, one graphic field, copies, ^XZ" do
    zpl = shipping_label.to_zpl

    expect(zpl).to start_with("^XA^PW812^LL1218^LH0,0^FO0,0^GFA,")
    expect(zpl).to end_with("^FS^PQ1^XZ\n")
    expect(zpl.scan("^XA").size).to eq(1)
  end

  it "sizes the label and its field from the page at dpi:, 203 by default" do
    label = ZPLReader.labels(shelf_label.to_zpl).first

    expect([label.width, label.length]).to eq([Stationery::Raster.pixels(Stationery::Units.mm(100), 203),
                                               Stationery::Raster.pixels(Stationery::Units.mm(60), 203)])
    expect([label.width, label.length]).to eq([800, 480])
    expect(label.row_bytes).to eq(100)
    expect(label.total).to eq(100 * 480)
    expect(label.rows.size).to eq(480)
    expect(label.crc_ok).to be(true)
  end

  it "takes the resolutions of ZPL printers and refuses others" do
    label = ZPLReader.labels(shipping_label.to_zpl(dpi: 300)).first

    expect([label.width, label.length, label.row_bytes]).to eq([1200, 1800, 150])
    expect(ZPLReader.labels(shipping_label.to_zpl(dpi: 152)).first.width).to eq(608)
    expect(ZPLReader.labels(shipping_label.to_zpl(dpi: 600)).first.width).to eq(2400)
    expect { shipping_label.to_zpl(dpi: 200) }.to raise_error(ArgumentError, /152, 203, 300 or 600/)
  end

  [[:shelf_label, 203], [:shelf_label, 300], [:shipping_label, 203], [:shipping_label, 300]].each do |name, dpi|
    it "prints the dots to_png(monochrome:) draws, for the #{name.to_s.tr("_", " ")} at #{dpi} dpi" do
      document = send(name)
      label = ZPLReader.labels(document.to_zpl(dpi:)).first
      png = document.to_png(monochrome: { dpi: }).first

      expect(label.dots).to eq(ZPLReader.png_dots(png))
      expect(label.dots.join.count("1")).to be > 1000
    end
  end

  it "prints a JPEG photo dithered, the dots to_png(monochrome:) draws" do
    path = jpeg_path("scaled")
    document = SpecDocument.build { image path, width: 72 }
    label = ZPLReader.labels(document.to_zpl).first

    expect(document.warnings.to_a).to be_empty
    expect(label.dots).to eq(ZPLReader.png_dots(document.to_png(monochrome: true).first))
    expect(label.dots.join.count("1")).to be > 1000
  end

  it "writes the same dots as plain hex for printers that do not take Z64" do
    hex = shelf_label.to_zpl(compression: :hex)
    label = ZPLReader.labels(hex).first

    expect(hex).not_to include(":Z64:")
    expect(label.dots).to eq(ZPLReader.labels(shelf_label.to_zpl).first.dots)
    expect { shelf_label.to_zpl(compression: :lzw) }.to raise_error(ArgumentError, /:z64 or :hex/)
  end

  it "leaves the padding of each row white, past the width of the label" do
    label = ZPLReader.labels(SpecDocument.build { box(background: "#000000") { text "x" } }.to_zpl).first

    expect(label.width % 8).not_to eq(0)
    padding = label.rows.map { |row| row.unpack1("B*")[label.width..] }

    expect(padding.uniq).to eq(["0" * ((label.row_bytes * 8) - label.width)])
  end

  it "applies the class's monochrome settings, with dpi: over its dpi" do
    snapped = Class.new(SpecDocument) do
      monochrome dpi: 300, snap: true
      define_method(:view_template) { box(background: "#EEEEEE", width: 50, height: 30) { nil } }
    end.new

    expect(ZPLReader.labels(snapped.to_zpl).first.width).to eq(1250)
    expect(ZPLReader.labels(snapped.to_zpl).first.dots.join).not_to include("1")
    expect(snapped.warnings).to be_empty
    expect(ZPLReader.labels(snapped.to_zpl(dpi: 203)).first.width).to eq(846)
  end

  it "dithers and reports what is not black or white without snap:, as monochrome does" do
    shelf_label.to_zpl

    expect(shelf_label.warnings.map(&:class).uniq).to eq([Stationery::Warnings::NotMonochrome])
  end

  it "refuses monochrome: false, since a label printer prints one bit" do
    expect { shelf_label.to_zpl(monochrome: false) }.to raise_error(ArgumentError, /one bit/)
  end

  it "prints copies:, by default those of the class's print hints" do
    two = Class.new(SpecDocument) do
      print copies: 2
      define_method(:view_template) { text "hi" }
    end.new

    expect(shelf_label.to_zpl(copies: 3)).to include("^PQ3^XZ")
    expect(two.to_zpl).to include("^PQ2^XZ")
    expect(two.to_zpl(copies: 1)).to include("^PQ1^XZ")
    expect { two.to_zpl(copies: 0) }.to raise_error(ArgumentError, /copies:/)
  end

  it "writes the pages chosen, in order, one label each" do
    document = SpecDocument.build do
      text "one"
      page_break
      text "two"
      page_break
      text "three"
    end

    expect(ZPLReader.labels(document.to_zpl).size).to eq(3)
    expect(ZPLReader.labels(document.to_zpl(pages: [3, 1])).map(&:dots))
      .to eq(ZPLReader.labels(document.to_zpl).values_at(2, 0).map(&:dots))
    expect { document.to_zpl(pages: 4) }.to raise_error(ArgumentError, /page 4/)
  end

  it "writes to a path or an IO when given one" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "label.zpl")
      zpl = shelf_label.to_zpl(path)
      io = StringIO.new
      shelf_label.to_zpl(io)

      expect(File.binread(path)).to eq(zpl)
      expect(io.string).to eq(zpl)
    end
  end

  it "refuses what only a PDF has" do
    expect { shelf_label.to_zpl(encrypt: {}) }.to raise_error(ArgumentError, /to_zpl does not take encrypt:/)
    expect { shelf_label.to_zpl(nope: 1) }.to raise_error(ArgumentError, /unknown keyword: :nope/)
  end

  it "raises WarningsError in strict mode" do
    expect { shelf_label.to_zpl(strict: true) }.to raise_error(Stationery::WarningsError)
  end
end
