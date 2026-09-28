# frozen_string_literal: true

# Pictures held to poppler's (pdftoppm) of the same documents' PDFs: see
# spec/support/raster_references.rb for the documents and how to record them.
RSpec.describe "Pictures of a render against poppler's" do
  RasterReferences::DOCUMENTS.each_key do |name|
    it "draws #{name} as poppler draws its PDF, all but a few pixels" do
      ours = RasterReferences.render(name)
      reference = File.binread(RasterReferences.path(name))

      expect(RasterReferences.difference(ours, reference)).to be < 0.01
    end
  end
end
