# frozen_string_literal: true

RSpec.describe "OpenType fonts with CFF outlines" do
  def document(file, &)
    path = font_path(file)
    Class.new(SpecDocument) do
      font_family "OTF", regular: path
      default_text font: "OTF", size: 10
      define_method(:view_template, &)
    end.new.to_pdf
  end

  def font_program(pdf)
    reader = reader_for(pdf)
    descriptor = reader.objects.values.find { |object| object.is_a?(Hash) && object[:FontFile3] }
    reader.objects[descriptor[:FontFile3]]
  end

  it "embeds a name-keyed CFF font as CIDFontType0 over a subset of its CFF table" do
    pdf = document("SourceSans3-Latin.otf") { text "AVA Über" }

    expect(pdf).to include("/Subtype /CIDFontType0", "/FontFile3", "/Subtype /CIDFontType0C", "/W [")
    expect(pdf).not_to include("/CIDToGIDMap")
    expect(pdf).to match(%r{/BaseFont /[A-Z]{6}\+SourceSans3-Regular})
    expect(text_of(pdf)).to include("AVA", "Über")
    expect(reader_for(pdf).page_count).to eq(1)
    expect(Stationery::Fonts::CFF.new(font_program(pdf).unfiltered_data).num_glyphs).to eq(160)
  end

  it "writes CID-keyed text as CIDs and maps them back to Unicode" do
    pdf = document("NotoSansJP-Subset.otf") { text "日本語" }

    expect(pdf).to include("/Registry (Adobe) /Ordering (Identity) /Supplement 0")
    expect(page_contents(pdf).first).to include("<4EFC511693E4>") # CIDs 20220, 20758, 37860
    expect(text_of(pdf)).to eq("日本語")
    expect(reader_for(pdf).pages.first.text).to eq("日本語")
  end

  it "embeds less than the whole font" do
    program = font_program(document("NotoSansJP-Subset.otf") { text "日本語" }).unfiltered_data
    otf = Stationery::Fonts::TrueType.new(File.binread(font_path("NotoSansJP-Subset.otf")))

    expect(program.bytesize).to be < otf.table_data("CFF ").bytesize
    expect(program.bytesize).to be < otf.data.bytesize / 2
  end
end
