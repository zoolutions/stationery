# frozen_string_literal: true

require "json"

# Every form of `to_pdf` that was there before pages were sealed as they are
# painted writes what `main` wrote: see RenderDigests for the fixture.
RSpec.describe Stationery::Document, "#to_pdf" do
  before do
    allow(Time).to receive(:now).and_return(RenderDigests::FROZEN)
    stub_const("Stationery::VERSION", RenderDigests.fixture.fetch("version"))
  end

  def digests(pdf) = RenderDigests.comparable(RenderDigests.digest(pdf))

  RenderDigests.names.each do |name|
    it "writes #{name} to a String as main does, object for object" do
      expect(digests(RenderDigests.document(name).to_pdf)).to eq(RenderDigests.recorded(name, "string"))
    end

    it "streams #{name} to a block as main does, object for object" do
      pdf = RenderDigests.streamed(RenderDigests.document(name))

      expect(digests(pdf)).to eq(RenderDigests.recorded(name, "block"))
    end
  end

  it "holds a platform with another zlib to the objects alone" do
    allow(RenderDigests).to receive(:environment).and_return("another zlib")

    expect(RenderDigests.recorded("text", "string").keys).to eq(["objects"])
    expect(digests(RenderDigests.document("text").to_pdf)).to eq(RenderDigests.recorded("text", "string"))
  end

  it "writes the same bytes when the font memos start over on every word" do
    document = RenderDigests.document("text")
    pdf = document.to_pdf
    stub_const("Stationery::Fonts::Font::MEMO_BYTES", 16)

    expect(RenderDigests.document("text").to_pdf).to eq(pdf)
  end

  it "writes the same bytes whether its pages are sealed as they are painted or not" do
    document = RenderDigests.document("table")
    pdf = document.to_pdf
    allow(Stationery::PDF::PageSealer).to receive(:new).and_wrap_original do |original, **options|
      original.call(**options, final: false)
    end

    expect(RenderDigests.document("table").to_pdf).to eq(pdf)
    expect(Stationery::PDF::PageSealer).to have_received(:new).with(final: true)
  end

  it "tells the objects of two files apart" do
    one = SpecDocument.build { text "one" }.to_pdf
    two = SpecDocument.build { text "two" }.to_pdf

    expect(RenderDigests.objects(one)).to include("/Type /Catalog").and include(" Tf\n").and include("endstream\n")
    expect(RenderDigests.digest(one)).not_to eq(RenderDigests.digest(two))
    expect(RenderDigests.inflate("not deflated")).to eq("not deflated")
  end
end
