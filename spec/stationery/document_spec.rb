# frozen_string_literal: true

require "stringio"
require "tmpdir"

RSpec.describe Stationery::Document do
  it "renders a binary PDF string" do
    pdf = SpecDocument.build { text "hi" }.to_pdf

    expect(pdf).to start_with("%PDF-1.7")
    expect(pdf.encoding).to eq(Encoding::BINARY)
  end

  it "writes to a path or an IO as well as returning the bytes" do
    doc = SpecDocument.build { text "hi" }
    io = StringIO.new(+"".b)
    path = File.join(Dir.mktmpdir, "out.pdf")

    expect(doc.to_pdf(io)).to eq(io.string)
    doc.to_pdf(path)
    expect(File.binread(path)).to start_with("%PDF")
  end

  it "uses the class's page size and margins" do
    pdf = SpecDocument.build { text "x" }.to_pdf
    page = reader_for(pdf).pages.first

    expect(page.attributes[:MediaBox]).to eq([0, 0, 300, 200])
    expect(positions_of(pdf).first.first).to eq(20)
  end

  it "inherits and overrides configuration in subclasses" do
    a4 = Class.new(SpecDocument) do
      page size: :a4, margin: 50
      default_text size: 14, color: "#FF0000"
      def view_template = text("big")
    end
    pdf = a4.new.to_pdf

    expect(reader_for(pdf).pages.first.attributes[:MediaBox]).to eq([0, 0, 595.28, 841.89])
    expect(page_contents(pdf).first).to include("/F1 14 Tf", "1 0 0 rg")
    expect(SpecDocument.new.page_options[:size]).to eq([300, 200])
  end

  it "writes metadata from the class and from the instance" do
    doc = Class.new(SpecDocument) do
      metadata title: "Invoice 42", author: "Acme"
      def metadata = super.merge(subject: "Billing")
      def view_template = text("x")
    end
    info = reader_for(doc.new.to_pdf).info

    expect(info).to include(Title: "Invoice 42", Author: "Acme", Subject: "Billing")
  end

  it "draws page templates on every page after pagination, with page numbers" do
    doc = Class.new(SpecDocument) do
      page_template do |page|
        box(at: [page.margin[3], page.height - 15], width: page.content_box.width) do
          text "Page #{page.number} of #{page.count}", align: :center, size: 7
        end
      end
      def view_template = 30.times { |i| text("line #{i}") }
    end
    pdf = doc.new.to_pdf
    count = page_count(pdf)

    expect(count).to be > 1
    expect(strings_of(pdf).grep(/Page/)).to eq((1..count).map { |n| "Page #{n} of #{count}" })
  end

  it "paints background templates underneath the content" do
    doc = Class.new(SpecDocument) do
      page_template(layer: :background) do |page|
        canvas(at: [0, 0], width: page.width, height: page.height) do |c, rect|
          c.fill_rect(rect.x, rect.y, rect.width, rect.height, color: "#FAF7F2")
        end
      end
      def view_template = text("over the background")
    end
    content = page_contents(doc.new.to_pdf).first

    expect(content.index("0.9804 0.9686 0.949 rg")).to be < content.index("BT")
  end

  it "exposes overflow warnings instead of raising" do
    doc = SpecDocument.build { box(break_inside: :avoid) { 40.times { |i| text "row #{i}" } } }
    doc.to_pdf

    expect(doc.warnings.map(&:page)).to eq([1])
  end

  it "explains a missing font family" do
    bare = Class.new(described_class) { def view_template = text("x") }

    expect { bare.new.to_pdf }.to raise_error(Stationery::Error, /font_family/)
  end
end
