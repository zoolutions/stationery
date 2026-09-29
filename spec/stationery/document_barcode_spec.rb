# frozen_string_literal: true

RSpec.describe Stationery::Document, "#barcode" do
  let(:labels) do
    Class.new(SpecDocument) do
      page size: "4in x 3in", margin: 12

      define_method(:view_template) do
        barcode "SX00427719", height: 50
        spacer 8
        barcode "400638133393", type: :ean13, height: 40
        spacer 8
        barcode "https://example.com/p/42", type: :qr
      end
    end.new
  end

  def fields(zpl) = zpl.scan(/\^FO\d+,\d+\^B[YQX].*?\^FS/)

  it "draws each barcode as one filled path of vector bars in the PDF" do
    content = page_contents(SpecDocument.build { barcode "12345678", height: 20 }.to_pdf).first

    expect(content.scan(/ re\b/).size).to eq(Stationery::Barcode.build(:code128, "12345678").bars.size)
    expect(content.scan(/^f$|\bf\n/).size).to eq(1)
  end

  it "is as wide as its modules and quiet zones, and shrinks its module to fit" do
    node = Stationery::Layout::Barcode.new(Stationery::Barcode.build(:code128, "12345678"), type: :code128)

    expect(node.size(1000)).to eq([99, 36, 1])
    expect(node.size(49.5)).to eq([49.5, 36, 0.5])
    qr = Stationery::Layout::Barcode.new(Stationery::Barcode.build(:qr, "x"), type: :qr, width: 58)
    expect(qr.size(1000)).to eq([58, 58, 2])
  end

  it "puts a monochrome barcode on the dot grid, a whole number of dots a module" do
    png = SpecDocument.build { barcode "12345678", module_size: 1, height: 20 }.to_png(monochrome: true).first
    row = ZPLReader.png_dots(png)[80]
    widths = row.scan(/1+/).map(&:size).uniq.sort

    expect(widths).to eq([3, 6, 9]) # 1 pt is 2.8 dots at 203 dpi: 3 dots a module, bars of 1 to 3 modules
  end

  it "leaves barcodes in the picture of a ZPL label unless asked" do
    zpl = labels.to_zpl

    expect(fields(zpl)).to be_empty
    expect(ZPLReader.labels(zpl).first.dots).to eq(ZPLReader.png_dots(labels.to_png(monochrome: true).first))
  end

  it "has the printer draw them with native: true, where the picture had them" do
    zpl = labels.to_zpl(native: true)

    expect(fields(zpl)).to eq(["^FO62,34^BY3^BCN,141,N,N,N,N^FD>:SX>500427719^FS",
                               "^FO65,197^BY3^BEN,113,N,N^FD400638133393^FS",
                               "^FO56,345^BQN,2,6^FDMM,B0024https://example.com/p/42^FS"])
    expect(ZPLReader.labels(zpl).first.dots.join.count("1")).to be < 200
  end

  it "draws a Data Matrix as square modules, and has the printer draw it with ^BX at its size" do
    document = Class.new(SpecDocument) do
      page size: "4in x 3in", margin: 12

      define_method(:view_template) { barcode "SX0042771903", type: :datamatrix, module_size: 3 }
    end.new
    zpl = document.to_zpl(native: true)

    expect(fields(zpl)).to eq(["^FO42,42^BXN,8,200,14,14,6,_,1^FDSX0042771903^FS"])
    expect(ZPLReader.labels(zpl).first.dots.join.count("1")).to eq(0)
    expect(ZPLReader.labels(document.to_zpl).first.dots.join.count("1")).to be > 3000
  end

  it "takes native: per barcode, over the render's" do
    document = Class.new(SpecDocument) do
      define_method(:view_template) do
        barcode "ONE", native: true
        barcode "TWO"
        barcode "THREE", native: false
      end
    end.new

    expect(fields(document.to_zpl).map { |field| field[/\^FD(.*)\^FS/, 1] }).to eq([">:ONE"])
    expect(fields(document.to_zpl(native: true)).map { |field| field[/\^FD(.*)\^FS/, 1] }).to eq([">:ONE", ">:TWO"])
    expect(fields(document.to_zpl(native: false)).size).to eq(1)
  end

  it "keeps in the picture what the printer cannot draw as it is" do
    document = Class.new(SpecDocument) do
      page size: [600, 300]

      define_method(:view_template) do
        box(rotate: 90, width: 100) { barcode "TURNED" }
        barcode "Grüße", type: :qr
        barcode "WIDE", module_size: 4
        barcode "PALE", color: "#CCCCCC"
      end
    end.new

    expect(fields(document.to_zpl(native: true))).to be_empty
  end

  it "is a figure in a tagged PDF, described by its kind and data" do
    document = Class.new(SpecDocument) do
      tagged
      metadata lang: "en"
      define_method(:view_template) { barcode "SX00427719" }
    end.new
    document.to_pdf

    expect(document.warnings.to_a).to be_empty
    expect(struct_tree(document.to_pdf).flatten).to include("Code 128: SX00427719")
  end

  it "refuses what a barcode cannot hold where it is written" do
    expect { SpecDocument.build { barcode "12", type: :ean13 }.to_pdf }.to raise_error(ArgumentError, /12 or 13/)
  end
end
