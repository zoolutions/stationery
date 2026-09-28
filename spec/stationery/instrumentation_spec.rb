# frozen_string_literal: true

RSpec.describe Stationery::Instrumentation do
  # Records [name, payload] pairs in the order the events finish, like a subscriber would see them.
  let(:recorder) do
    Class.new do
      attr_reader :events

      def initialize = @events = []

      def instrument(name, payload = {})
        result = yield payload
        @events << [name, payload]
        result
      end
    end.new
  end

  let(:document) do
    path = image_path("rgb.jpg")
    SpecDocument.build do
      text "hi"
      image path, width: 20
      image path, width: 10
      html "<p>rich <b>text</b></p>"
    end
  end

  before do
    Stationery.instrumenter = recorder
    Stationery::Images::Cache.clear
    Stationery::Fonts::Registry.clear
  end

  after { Stationery.instrumenter = nil }

  def names = recorder.events.map(&:first)
  def payload(name) = recorder.events.find { |event, _| event == name }.last
  def font_events = recorder.events.filter_map { |name, event| event if name == "font.stationery" }

  it "defaults to a null instrumenter that just yields" do
    Stationery.instrumenter = nil

    expect(Stationery.instrumenter).to be_a(described_class::Null)
    expect(Stationery.instrument("x.stationery", a: 1) { |payload| payload[:a] + 1 }).to eq(2)
  end

  it "emits one event per phase, inner phases finishing before the render" do
    document.to_pdf

    expect(names.last).to eq("render.stationery")
    expect(names.uniq).to contain_exactly("render.stationery", "build.stationery", "paginate.stationery",
                                          "write.stationery", "image.stationery", "font.stationery",
                                          "parse.stationery")
    expect(names.index("build.stationery")).to be < names.index("paginate.stationery")
    expect(names.index("paginate.stationery")).to be < names.index("write.stationery")
  end

  it "fills the render payload in once the PDF exists" do
    pdf = document.to_pdf

    expect(payload("render.stationery"))
      .to eq(document: document.class.name, pages: 1, bytes: pdf.bytesize, warnings: 0)
    expect(payload("paginate.stationery")).to eq(document: document.class.name, pages: 1)
    expect(payload("write.stationery")).to eq(document: document.class.name, bytes: pdf.bytesize)
    expect(payload("build.stationery")).to eq(document: document.class.name)
  end

  it "decodes an image once for two uses and reports its shape" do
    document.to_pdf

    expect(names.count("image.stationery")).to eq(1)
    expect(payload("image.stationery"))
      .to eq(format: "JPEG", width: 4, height: 3, bytes: File.size(image_path("rgb.jpg")))
  end

  it "reports a lossless WebP as WebP" do
    Stationery::Images.load(image_path("webp/photo.webp"))

    expect(payload("image.stationery")).to eq(format: "WebP", width: 40, height: 32, bytes: 2958)
  end

  it "reports font parsing on a registry miss and subsetting on every render" do
    document.to_pdf
    fonts = font_events

    expect(fonts).to include(path: "OpenSans-Regular.ttf", action: :parse)
    expect(fonts).to include(a_hash_including(font: "OpenSans-Regular", action: :subset))
    expect(fonts.find { |f| f[:action] == :subset }[:glyphs]).to be > 0

    recorder.events.clear
    document.to_pdf

    expect(font_events.map { |f| f[:action] }).to all(eq(:subset))
  end

  it "reports html and markdown parsing with the source size" do
    document.to_pdf
    SpecDocument.build { markdown "# hi" }.to_pdf

    expect(payload("parse.stationery")).to eq(format: :html, bytes: 23)
    expect(recorder.events.map(&:last)).to include(format: :markdown, bytes: 4)
  end
end
