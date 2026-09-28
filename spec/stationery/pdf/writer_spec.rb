# frozen_string_literal: true

RSpec.describe Stationery::PDF::Writer do
  subject(:writer) { described_class.new }

  def render(writer)
    pages = writer.add({ Type: :Pages, Kids: [], Count: 0 })
    root = writer.add({ Type: :Catalog, Pages: pages })
    info = writer.add({ Producer: Stationery::PDF::TextString.new("Stationery") })
    writer.render(root:, info:)
  end

  it "starts with a PDF 1.7 header and a binary comment line" do
    pdf = render(writer)

    expect(pdf).to start_with("%PDF-1.7\n%\xE2\xE3\xCF\xD3\n".b)
    expect(pdf.encoding).to eq(Encoding::BINARY)
    expect(pdf).to end_with("%%EOF\n")
  end

  it "fills a reserved reference later so objects can point forward" do
    later = writer.reserve
    writer.add({ Parent: later })
    writer.set(later, { Type: :Pages })

    expect(render(writer)).to include("1 0 obj\n<</Type /Pages>>").and include("2 0 obj\n<</Parent 1 0 R>>")
  end

  it "refuses to render while a reserved reference is still unset" do
    writer.reserve

    expect { render(writer) }.to raise_error(Stationery::Error, /object 1 reserved but never set/)
  end

  it "writes byte-accurate cross-reference offsets" do
    writer.add(Stationery::PDF::Stream.new("q Q"))
    pdf = render(writer)

    xref_at = pdf[/startxref\n(\d+)/, 1].to_i
    expect(pdf.byteslice(xref_at, 4)).to eq("xref")
    offsets = pdf.byteslice(xref_at..).scan(/^(\d{10}) 00000 n /).flatten.map(&:to_i)
    offsets.each_with_index do |offset, index|
      expect(pdf.byteslice(offset, "#{index + 1} 0 obj".bytesize)).to eq("#{index + 1} 0 obj")
    end
  end

  it "writes a trailer with Size, Root, Info and a document ID" do
    pdf = render(writer)

    expect(pdf).to match(%r{trailer\n<</Size 4 /Root 2 0 R /Info 3 0 R /ID \[<\h{32}> <\h{32}>\]>>})
  end

  it "produces a file PDF::Reader can open" do
    expect(reader_for(render(writer)).page_count).to eq(0)
  end

  describe "streaming" do
    def fill(writer)
      later = writer.reserve
      first = writer.add(Stationery::PDF::Stream.new("q Q"))
      writer.flush
      writer.set(later, { After: first })
    end

    it "keeps the String in numbered order, flushed or not" do
      fill(writer)
      pdf = render(writer)

      expect(pdf.index("1 0 obj")).to be < pdf.index("2 0 obj")
    end

    it "hands a sink the file in flush order, with offsets that hold" do
      pieces = []
      streaming = described_class.new(sink: ->(bytes) { pieces << bytes.dup })
      fill(streaming)

      expect(render(streaming)).to eq(pieces.sum(&:bytesize))
      file = pieces.join
      expect(file.index("2 0 obj")).to be < file.index("1 0 obj")
      xref_at = file[/startxref\n(\d+)/, 1].to_i
      offsets = file.byteslice(xref_at..).scan(/^(\d{10}) 00000 n /).flatten.map(&:to_i)
      offsets.each_with_index do |offset, index|
        expect(file.byteslice(offset, "#{index + 1} 0 obj".bytesize)).to eq("#{index + 1} 0 obj")
      end
      expect(reader_for(file).page_count).to eq(0)
    end

    it "refuses to set an object a sink already has" do
      streaming = described_class.new(sink: ->(_) {})
      stream = streaming.add(Stationery::PDF::Stream.new("q Q"))
      streaming.flush

      expect { streaming.set(stream, {}) }.to raise_error(Stationery::Error, /already written/)
    end
  end

  context "with encryption" do
    subject(:writer) { described_class.new(encryption:) }

    let(:encryption) { Stationery::PDF::Encryption::StandardSecurity.new(owner_password: "o", algorithm: :rc4_128) }

    it "encrypts strings and stream data, but not the Encrypt dictionary or the file ID" do
      writer.add(Stationery::PDF::Stream.new("q Q"))
      pdf = render(writer)
      id = encryption.file_id.unpack1("H*").upcase

      expect(pdf).not_to include("(Stationery)")
      expect(pdf).to match(%r{trailer\n<<.*/ID \[<#{id}> <#{id}>\] /Encrypt 5 0 R>>})
      expect(pdf).to include("5 0 obj\n<</Filter /Standard /V 2 /R 3")
      expect(reader_for(pdf).info).to eq(Producer: "Stationery")
    end
  end
end
