# frozen_string_literal: true

require "stationery/minitest"

RSpec.describe Stationery::Testing::Inspector do
  describe "#colors" do
    it "lists the colours the pages fill and stroke with, once each, as #RRGGBB" do
      pdf = SpecDocument.build do
        text "black"
        text "red", color: "#ff0000"
        box(background: [0, 0, 0, 100], border: { width: 1, color: "#00F" }) { text "cmyk box" }
        page_break
        text "red again", color: "#FF0000"
      end.to_pdf

      expect(described_class.new(pdf).colors).to eq(["#000000", "#0000FF", "#FF0000"])
    end

    it "lists a gradient as a shading and an image as an image, unless it is one bit deep" do
      svg = '<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10"><linearGradient id="g">' \
            '<stop offset="0" stop-color="#000"/><stop offset="1" stop-color="#888"/></linearGradient>' \
            '<rect width="10" height="10" fill="url(#g)"/></svg>'
      png = PngFactory.build(width: 1, height: 1, color_type: 2, rows: [[200, 100, 50]])
      document = SpecDocument.build do
        svg svg
        image StringIO.new(png), width: 10
      end

      expect(described_class.new(document.to_pdf).colors).to eq(%w[image shading])
      expect(described_class.new(document.to_pdf(monochrome: { snap: true })).colors).to eq(["#000000"])
    end

    it "is empty for a page that sets no colour" do
      expect(described_class.new(SpecDocument.build { spacer 1 }).colors).to eq([])
    end
  end

  describe "have_pdf_colors" do
    let(:grey) { SpecDocument.build { text "grey", color: "#888888" } }

    it "matches the colours a PDF paints with, in any order" do
      expect(SpecDocument.build { text "x" }).to have_pdf_colors("#000000")
      expect(grey).to have_pdf_colors("#888888")
      expect(grey).not_to have_pdf_colors("#000000")
    end

    it "says what it found" do
      matcher = have_pdf_colors("#000000", "#FFFFFF")
      matcher.matches?(grey)

      expect(matcher.description).to eq('paint with colors "#000000", "#FFFFFF"')
      expect(matcher.failure_message).to eq('expected PDF to paint with colors "#000000", "#FFFFFF", got "#888888"')
    end

    it "is a Minitest assertion" do
      host = Class.new do
        include Stationery::Testing::Assertions

        attr_reader :calls

        def assert(test, msg = nil) = (@calls ||= []) << [test, msg]
      end.new
      host.assert_pdf_colors(grey, ["#888888"])

      expect(host.calls).to eq([[true, 'expected PDF to paint with colors "#888888", got "#888888"']])
    end
  end
end
