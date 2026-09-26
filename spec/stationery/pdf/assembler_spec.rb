# frozen_string_literal: true

RSpec.describe Stationery::PDF::Assembler do
  let(:resources) { Stationery::Resources.new }
  let(:font) { Stationery::Fonts::Font.new(Stationery::Fonts::Registry.load(font_path("OpenSans-Regular.ttf"))) }

  def page_with(&)
    Stationery::Page.new(size: :a4).tap { |page| yield Stationery::Canvas.new(page, resources) }
  end

  it "writes a readable PDF whose text extracts, including non-ASCII" do
    page = page_with { |c| c.text("Müller & Söhne €12", x: 50, y: 100, font:, size: 12) }
    pdf = described_class.new(pages: [page], resources:, info: { Title: "Faktura" }).render

    expect(text_of(pdf)).to eq("Müller & Söhne €12")
    expect(page_count(pdf)).to eq(1)
    expect(reader_for(pdf).info).to include(Title: "Faktura", Producer: /Stationery/)
  end

  it "embeds a font once and lists on each page only the resources it uses" do
    image = Stationery::Images.load(image_path("rgb.jpg"))
    first = page_with { |c| c.text("One", x: 10, y: 10, font:, size: 10) }
    second = page_with do |c|
      c.text("Two", x: 10, y: 10, font:, size: 10)
      c.image(image, x: 0, y: 0, width: 10, height: 10)
    end
    pdf = described_class.new(pages: [first, second], resources:).render
    pages = reader_for(pdf).pages

    expect(pdf.scan("/Subtype /Type0").size).to eq(1)
    expect(pages[0].xobjects).to be_empty
    expect(pages[1].xobjects.keys).to eq([:Im1])
    expect(image_count(pdf)).to eq(1)
  end

  it "writes link annotations with ASCII literal URIs" do
    page = page_with { |c| c.link(10, 10, 50, 12, "https://example.com/a?b=c") }
    pdf = described_class.new(pages: [page], resources:).render

    expect(pdf).to include("/URI (https://example.com/a?b=c)")
    expect(link_rects(pdf)).to eq([[10, 819.89, 60, 831.89]])
  end
end
