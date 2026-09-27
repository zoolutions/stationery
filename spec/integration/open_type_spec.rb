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

  it "embeds a name-keyed CFF font as CIDFontType0 over the OpenType file" do
    pdf = document("SourceSans3-Latin.otf") { text "AVA Über" }

    expect(pdf).to include("/Subtype /CIDFontType0", "/FontFile3", "/Subtype /OpenType", "/W [")
    expect(pdf).not_to include("/CIDToGIDMap")
    expect(pdf).to include("/BaseFont /SourceSans3-Regular")
    expect(text_of(pdf)).to include("AVA", "Über")
    expect(reader_for(pdf).page_count).to eq(1)
  end

  it "writes CID-keyed text as CIDs and maps them back to Unicode" do
    pdf = document("NotoSansJP-Subset.otf") { text "日本語" }

    expect(pdf).to include("/Registry (Adobe) /Ordering (Identity) /Supplement 0")
    expect(page_contents(pdf).first).to include("<4EFC511693E4>") # CIDs 20220, 20758, 37860
    expect(text_of(pdf)).to eq("日本語")
    expect(reader_for(pdf).pages.first.text).to eq("日本語")
  end
end
