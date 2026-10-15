# frozen_string_literal: true

# A whole render inside a non-main Ractor, Ruby 4.0 and later (Ractor#value):
# every cache it fills is that Ractor's own (Stationery::Store), every
# constant it reads is shareable, and the document class was finalized at
# boot, so the PDF is the main Ractor's, byte for byte.
RSpec.describe "a render inside a non-main Ractor" do
  describe "of three pages of text, shapes, a JPEG, a table, a QR code and a footer" do
    let(:subject_call) { -> { CanaryDocuments.pinned { CanaryDocuments::Report.new.to_pdf } } }

    it_behaves_like "runs inside a non-main Ractor"

    it "is that document" do
      pdf = CanaryDocuments.pinned { CanaryDocuments::Report.new.to_pdf }

      expect(pdf).to have_page_count(3)
      expect(pdf).to have_image_count(1) # one XObject, drawn on every page
      expect(pdf).to have_pdf_text_on_page(3, "Section 3")
    end
  end

  # A parse never changes once built, so it can be made shareable at boot and
  # handed to a Ractor as it is, not copied.
  describe "with a font parsed on the main Ractor" do
    let(:subject_call) do
      lambda do |ttf|
        gids = "AVATAR office".each_char.map { |char| ttf.glyph_id(char.ord) }
        [Ractor.shareable?(ttf), ttf.postscript_name, gids.map { |gid| ttf.advance(gid) },
         gids.each_cons(2).sum { |left, right| ttf.kerning.adjust(left, right) }, ttf.ligatures.substitute(gids)]
      end
    end

    it_behaves_like "runs inside a non-main Ractor", inputs: defined?(Ractor) ? [CanaryDocuments.shared_font] : []
  end
end
