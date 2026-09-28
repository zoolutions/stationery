# frozen_string_literal: true

require "stationery/testing/inspector"

# What is on each page and in the file, in top-left points, in a stable order.
RSpec.describe Stationery::Testing::Inspector, "#layout" do
  let(:document) do
    photo = image_path("rgb.jpg")
    Class.new(SpecDocument) do
      metadata title: "Layout", author: "Acme", lang: "en"
      tagged
      print copies: 2

      define_method(:view_template) do
        text "Hello world", bookmark: "Start"
        text "Bold words", weight: :bold, size: 14
        image photo, width: 40
        text "Visit", link: "https://example.com"
        text "Go to the end", link: "#end"
        text_field "name", value: "Astrid", width: 100
        page_break
        text "The end", anchor: "end", bookmark: { title: "End", level: 2 }
      end
    end.new
  end
  let(:layout) { described_class.new(document).layout }
  let(:first) { layout[:pages].first }

  it "gives each page its number, label and size" do
    expect(layout[:pages].map { |page| page.slice(:number, :label, :width, :height) })
      .to eq([{ number: 1, label: nil, width: 300.0, height: 200.0 },
              { number: 2, label: nil, width: 300.0, height: 200.0 }])
  end

  it "lists the text lines top to bottom, each where it starts, with its font and size" do
    lines = first[:text]

    expect(lines.map { |line| line[:text] }).to eq(["Hello world", "Bold words", "Visit", "Go to the end"])
    expect(lines.map { |line| line[:x] }).to all(eq(20.0))
    expect(lines.map { |line| line[:y] }).to eq(lines.map { |line| line[:y] }.sort)
    expect(lines.first[:y]).to be_between(20, 32)
    expect(lines.first.slice(:font, :size)).to eq(font: "OpenSans-Regular", size: 10.0)
    expect(lines[1].slice(:font, :size)).to eq(font: "OpenSans-Bold", size: 14.0)
  end

  it "splits a line where the font changes" do
    doc = SpecDocument.build { text "plain <b>bold</b> plain", markup: true }
    line = described_class.new(doc).layout[:pages].first[:text]

    expect(line.map { |run| [run[:text], run[:font]] })
      .to eq([%w[plain OpenSans-Regular], %w[bold OpenSans-Bold], %w[plain OpenSans-Regular]])
    expect(line.map { |run| run[:y] }.uniq.size).to eq(1)
    expect(line.map { |run| run[:x] }).to eq(line.map { |run| run[:x] }.sort)
  end

  it "lists the images with their rectangles and pixel sizes" do
    image = first[:images].first

    expect(first[:images].size).to eq(1)
    expect(image.slice(:x, :width)).to eq(x: 20.0, width: 40.0)
    expect(image[:y]).to be > first[:text][1][:y]
    expect(image[:height]).to be > 0
    expect(image[:pixels]).to match([Integer, Integer])
  end

  it "lists the links with their rectangles and targets" do
    links = first[:links]

    expect(links.map { |link| link.except(:x, :y, :width, :height, :top) })
      .to eq([{ uri: "https://example.com" }, { page: 2 }])
    expect(links.first[:x]).to eq(20.0)
    expect(links.last[:top]).to be_between(0, 200)
  end

  it "lists the form fields with their values" do
    field = first[:fields].first

    expect(field.slice(:name, :type, :value, :width)).to eq(name: "name", type: :text, value: "Astrid", width: 100.0)
  end

  it "names the kind of each button and the state that turns it on" do
    doc = SpecDocument.build do
      checkbox "terms", checked: true, label: "I accept"
      radio "plan", "basic", label: "Basic"
      radio "plan", "pro", checked: true, label: "Pro"
      select "country", options: %w[Sweden Norway], value: "Norway"
    end
    fields = described_class.new(doc).layout[:pages].first[:fields]

    expect(fields.map { |field| field.slice(:name, :type, :value, :state) })
      .to eq([{ name: "terms", type: :checkbox, value: "Yes", state: "Yes" },
              { name: "plan", type: :radio, value: "pro", state: "basic" },
              { name: "plan", type: :radio, value: "pro", state: "pro" },
              { name: "country", type: :choice, value: "Norway" }])
  end

  it "reads the file: metadata without dates, outline, structure, print hints" do
    expect(layout[:metadata]).to include(title: "Layout", author: "Acme", lang: "en")
    expect(layout[:metadata].keys).not_to include(:creation_date, :mod_date)
    expect(layout[:outline]).to eq([{ title: "Start", page: 1, top: 20.0,
                                      children: [{ title: "End", page: 2, top: 20.0, children: [] }] }])
    expect(layout.slice(:tagged, :conformance, :print)).to eq(tagged: true, conformance: [], print: { copies: 2 })
    expect(layout[:structure].flatten).to include(:Document, "Hello world")
  end

  it "has the warnings of the render when the subject is a document" do
    doc = SpecDocument.build { box(break_inside: :avoid) { 40.times { |i| text "row #{i}" } } }

    expect(described_class.new(doc).layout[:warnings]).to include(start_with("content"))
    expect(described_class.new(document.to_pdf).layout[:warnings]).to eq([])
  end

  it "reads two renders of one document the same, dates and all" do
    twice = Array.new(2) { described_class.new(document.class.new.to_pdf).layout }

    expect(twice.first).to eq(twice.last)
  end
end
