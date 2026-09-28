# frozen_string_literal: true

# What Stationery writes is read through the Inspector's own specs; these
# are the operators and pages it never writes.
RSpec.describe Stationery::Testing::MarkedText do
  def read(pdf) = described_class.read(reader_for(pdf).pages.first)
  def text_by_pdf_reader(pdf) = reader_for(pdf).pages.first.text(skip_zero_width: true)

  describe "#layout" do
    it "is pdf-reader's for text shown with ' and \"" do
      pdf = raw_pdf("BT /F1 10 Tf 10 TL 20 150 Td (one) Tj (two) ' 2 1 (three four) \" ET")

      expect(read(pdf).layout).to eq(text_by_pdf_reader(pdf))
      expect(text_of(pdf)).to eq("one\ntwo\nthree four")
    end

    it "reads a form the page draws where it is drawn, and no image" do
      content = "BT /F1 10 Tf 20 150 Td (on the page) Tj ET q 1 0 0 1 20 135 cm /Fm1 Do Q /Im1 Do"
      pdf = raw_pdf(content) do |writer, font|
        form = raw_form(writer, font, "BT /F1 10 Tf 0 5 Td (in the form) Tj ET")
        { Resources: { Font: { F1: font }, XObject: { Fm1: form, Im1: raw_image(writer) } } }
      end

      expect(read(pdf).layout).to eq(text_by_pdf_reader(pdf))
      expect(text_of(pdf)).to eq("on the page\nin the form")
      expect(read(pdf).unmarked).to eq(["on the page", "in the form"])
    end

    it "reads a sequence with ActualText once, whatever is marked inside it" do
      pdf = raw_pdf("BT /F1 10 Tf 20 150 Td (a ) Tj /Span <</ActualText (whole)>> BDC " \
                    "/P BMC (sh) Tj EMC [(ow) -20 (n)] TJ EMC ( b) Tj ET")

      expect(text_of(pdf)).to eq("a whole b")
    end

    it "gives a sequence that moves the pen nowhere the room of its text" do
      pdf = raw_pdf("BT /F1 10 Tf 20 150 Td /Span <</ActualText (mark)>> BDC [(x) 500] TJ EMC ET")

      expect(text_of(pdf)).to eq("mark")
    end

    it "reads what a sequence naming its properties shows" do
      pdf = raw_pdf("BT /F1 10 Tf 20 150 Td /Span /Named BDC (shown) Tj EMC ET") do |_writer, font|
        { Resources: { Font: { F1: font }, Properties: { Named: { Lang: "en" } } } }
      end

      expect(text_of(pdf)).to eq("shown")
    end

    it "leaves out a sequence that shows nothing" do
      pdf = raw_pdf("BT /F1 10 Tf 20 150 Td /Span <</ActualText (unseen)>> BDC EMC (seen) Tj ET")

      expect(text_of(pdf)).to eq("seen")
    end

    # The text is turned against the page, so it reads upright in a viewer.
    { 0 => "1 0 0 1", 90 => "0 1 -1 0", 180 => "-1 0 0 -1", 270 => "0 -1 1 0" }.each do |angle, matrix|
      it "puts a sequence where its glyphs are on a page rotated by #{angle}" do
        content = "BT /F1 10 Tf #{matrix} 150 100 Tm (first) Tj #{matrix} 120 60 Tm %s ET"
        plain = raw_pdf(format(content, "(second) Tj")) { { Rotate: angle } }
        marked = raw_pdf(format(content, "/Span <</ActualText (second)>> BDC (second) Tj EMC")) { { Rotate: angle } }

        expect(read(marked).layout).to eq(read(plain).layout)
        expect(read(plain).layout).to eq(text_by_pdf_reader(plain)).and include("first").and include("second")
      end
    end
  end
end
