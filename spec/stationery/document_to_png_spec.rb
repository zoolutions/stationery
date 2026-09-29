# frozen_string_literal: true

require "tmpdir"

RSpec.describe Stationery::Document, "#to_png" do
  def decode(png) = Stationery::Images::PNG.new(png)

  # [r, g, b] of the pixel at (x, y), or [v] in a grey or one-bit picture.
  def pixel(png, x, y)
    pixels = decode(png).pixels
    pixels.color[y][x * pixels.channels, pixels.channels]
  end

  def header(png) = png.byteslice(16, 10).unpack("NNCC")

  let(:boxes) do
    SpecDocument.build do
      box(background: "#FF0000", width: 50, height: 30) { nil }
      box(border: { width: 2, color: "#0000FF" }, width: 50, height: 30) { nil }
    end
  end

  it "answers a PNG per page, as big as the page at dpi:, 24-bit RGB" do
    pngs = boxes.to_png(dpi: 72)

    expect(pngs.size).to eq(1)
    expect(header(pngs.first)).to eq([300, 200, 8, 2])
    expect(header(boxes.to_png(dpi: 144).first)).to eq([600, 400, 8, 2])
  end

  it "draws what to_pdf draws, where it draws it" do
    png = boxes.to_png(dpi: 72).first

    expect(pixel(png, 40, 30)).to eq([255, 0, 0])
    expect(pixel(png, 10, 10)).to eq([255, 255, 255])
    expect(pixel(png, 21, 60)).to eq([0, 0, 255])
    expect(pixel(png, 40, 65)).to eq([255, 255, 255])
  end

  it "draws text from the outlines of its glyphs" do
    png = SpecDocument.build { text "HHHH", size: 30 }.to_png(dpi: 72).first
    dark = decode(png).pixels.color.flatten.count { |v| v < 100 }

    expect(dark).to be > 150
  end

  it "draws pages chosen by number, and every page by default" do
    document = SpecDocument.build do
      text "one"
      page_break
      text "two"
      page_break
      text "three"
    end

    expect(document.to_png(dpi: 10).size).to eq(3)
    expect(document.to_png(dpi: 10, pages: 2).size).to eq(1)
    expect(document.to_png(dpi: 10, pages: [1, 3]).size).to eq(2)
    expect(document.to_png(dpi: 10, pages: 2..3).size).to eq(2)
    expect { document.to_png(pages: 4) }.to raise_error(ArgumentError, /page 4/)
  end

  it "writes a file for one page to the path given, and numbers the files of several" do
    Dir.mktmpdir do |dir|
      boxes.to_png(File.join(dir, "boxes.png"), dpi: 10)
      two = SpecDocument.build do
        text "one"
        page_break
        text "two"
      end
      two.to_png(File.join(dir, "two.png"), dpi: 10)

      expect(Dir.children(dir).sort).to eq(%w[boxes.png two-1.png two-2.png])
      expect(File.binread(File.join(dir, "two-2.png"))).to eq(two.to_png(dpi: 10, pages: 2).first)
    end
  end

  it "draws one bit to a dot at the monochrome dpi when monochrome" do
    png = boxes.to_png(monochrome: true).first

    expect(header(png)).to eq([(300 * 203 / 72.0).ceil, (200 * 203 / 72.0).ceil, 1, 0])
    expect(pixel(png, 100, 80)).to eq([0])
    expect(pixel(png, 5, 5)).to eq([255])
    expect(header(boxes.to_png(monochrome: { dpi: 300 }).first).first(2)).to eq([1250, 834])
    expect(header(boxes.to_png(monochrome: true, dpi: 100).first).first(2)).to eq([417, 278])
  end

  it "applies the rules of monochrome: a light fill snapped away, and reported without snap:" do
    light = SpecDocument.build { box(background: "#EEEEEE", width: 50, height: 30) { nil } }

    expect(pixel(light.to_png(monochrome: { snap: true }).first, 100, 80)).to eq([255])
    light.to_png(monochrome: true)
    expect(light.warnings.map(&:class)).to eq([Stationery::Warnings::NotMonochrome])
  end

  it "draws a JPEG, decoded no larger than it needs" do
    path = jpeg_path("scaled")
    document = SpecDocument.build { image path, width: 32, height: 24 }
    image = Stationery::Images.load(path)
    allow(image).to receive(:pixels).and_call_original
    png = document.to_png(dpi: 72).first

    expect(document.warnings.to_a).to be_empty
    expect(image).to have_received(:pixels).with(at_least: [32, 24])
    expect(pixel(png, 20 + 16, 20 + 12)).not_to eq([255, 255, 255])
  end

  # The one-bit image a monochrome PDF embeds, as rows of "1" for black.
  def embedded_bitmap(pdf)
    objects = reader_for(pdf).objects
    stream = objects.values.map { objects.deref(it) }.grep(PDF::Reader::Stream).find { it.hash[:Subtype] == :Image }
    width, height = stream.hash.values_at(:Width, :Height)
    stride = (width + 7) / 8
    data = stream.unfiltered_data
    Array.new(height) { |y| data.byteslice(y * stride, stride).unpack1("B*")[0, width].tr("01", "10") }
  end

  photos = { "PNG" => File.join(RenderDigests::ROOT, "examples/assets/dunes.png"),
             "JPEG" => File.join(PdfHelpers::IMAGES, "jpeg/scaled.jpg") }
  photos.to_a.product([203, 300]).each do |(kind, path), dpi|
    it "draws a #{kind} photo off the dot grid at #{dpi} dpi dot for dot as the monochrome PDF embeds it" do
      document = SpecDocument.build do
        box(height: 1.1) { nil }
        image path, width: 50.2, height: 30.3
      end
      bitmap = embedded_bitmap(document.to_pdf(monochrome: { dpi: }))
      dots = ZPLReader.png_dots(document.to_png(monochrome: { dpi: }).first)
      left = ((20 * dpi / 72.0) + 0.5).floor
      top = ((21.1 * dpi / 72.0) + 0.5).floor
      drawn = dots[top, bitmap.size].map { it[left, bitmap.first.size] }

      expect(bitmap.size).to eq((30.3 * dpi / 72.0).round)
      expect(drawn.join.chars.zip(bitmap.join.chars).count { |a, b| a != b }).to eq(0)
      expect(dots[top + bitmap.size][left, bitmap.first.size]).to eq("0" * bitmap.first.size)
    end
  end

  it "refuses what only a PDF has when it is asked for, and leaves it alone from the class" do
    signed = Class.new(SpecDocument) do
      encrypt owner_password: "x"
      print copies: 2
      define_method(:view_template) { text "hi" }
    end

    expect(signed.new.to_png(dpi: 10).size).to eq(1)
    %i[sign encrypt conformance attachments print tagged].each do |option|
      expect { boxes.to_png(option => nil) }.to raise_error(ArgumentError, /#{option}: .*PDF/)
    end
  end

  RenderDigests::EXAMPLES.each do |name|
    it "draws the first page of examples/#{name}.rb, with ink on it" do
      png = RenderDigests.example(name).to_png(dpi: 18, pages: 1).first

      expect(decode(png).pixels.color.flatten.count { |v| v < 128 }).to be > 20
    end
  end

  it "raises WarningsError in strict mode, as to_pdf does" do
    document = Class.new(SpecDocument) do
      strict
      define_method(:view_template) { box(height: 400, break_inside: :avoid) { text "tall" } }
    end

    expect { document.new.to_png(dpi: 10) }.to raise_error(Stationery::WarningsError)
  end
end
