# frozen_string_literal: true

require "zlib"

RSpec.describe Stationery::PDF::Writer, "#render with object streams" do
  subject(:writer) { described_class.new(object_streams: true) }

  def render(writer)
    pages = writer.add({ Type: :Pages, Kids: [], Count: 0 })
    root = writer.add({ Type: :Catalog, Pages: pages })
    info = writer.add({ Producer: Stationery::PDF::TextString.new("Stationery") })
    writer.render(root:, info:)
  end

  def xref_of(pdf)
    at = pdf[/startxref\n(\d+)/, 1].to_i
    pdf.byteslice(at..)[/\A\d+ 0 obj\n(<<.*?>>)\nstream\n/m, 1]
  end

  it "packs every object that is not a stream into a deflated object stream" do
    writer.add(Stationery::PDF::Stream.new("q Q"))
    pdf = render(writer)

    expect(pdf).not_to include("/Type /Catalog")
    expect(pdf).to include("/Type /ObjStm /N 3")
    expect(pdf.scan(/^\d+ 0 obj/).size).to eq(3) # the content stream, the object stream and the xref stream
    objects = reader_for(pdf).objects
    expect(objects.deref(objects.trailer[:Root])).to include(Type: :Catalog)
  end

  it "ends with a cross-reference stream in place of the table and trailer" do
    pdf = render(writer)

    expect(pdf).not_to match(/^xref$|^trailer$/)
    expect(xref_of(pdf)).to match(%r{/Type /XRef .*/W \[1 4 2\]}m)
      .and match(%r{/Size 6 /Root 2 0 R /Info 3 0 R /ID \[<\h{32}> <\h{32}>\]})
    expect(reader_for(pdf).info).to eq(Producer: "Stationery")
  end

  it "closes an object stream at 200 objects" do
    450.times { writer.add({ Type: :StructElem }) }
    pdf = render(writer)

    expect(pdf.scan(%r{/Type /ObjStm /N (\d+)}).flatten.map(&:to_i)).to eq([200, 200, 53])
    expect(reader_for(pdf).objects[PDF::Reader::Reference.new(450, 0)]).to eq(Type: :StructElem)
  end

  it "keeps out an object added with add_unpacked, written as it is" do
    writer.add_unpacked({ Contents: Stationery::PDF::Verbatim.new("<00>") })
    pdf = render(writer)

    expect(pdf).to include("1 0 obj\n<</Contents <00>>>\nendobj")
  end

  it "packs what each flush of a sink writes, with the xref last" do
    pieces = []
    streaming = described_class.new(sink: ->(bytes) { pieces << bytes.dup }, object_streams: true)
    later = streaming.reserve
    first = streaming.add({ Type: :First })
    streaming.flush
    streaming.set(later, { After: first })

    expect(render(streaming)).to eq(pieces.sum(&:bytesize))
    file = pieces.join
    expect(file.scan(%r{/Type /ObjStm /N (\d+)}).flatten.map(&:to_i)).to eq([1, 4])
    expect(reader_for(file).objects[PDF::Reader::Reference.new(1, 0)]).to eq(After: PDF::Reader::Reference.new(2, 0))
  end

  context "with encryption" do
    subject(:writer) { described_class.new(encryption:, object_streams: true) }

    let(:encryption) { Stationery::PDF::Encryption::StandardSecurity.new(owner_password: "o", algorithm: :aes_256) }

    it "encrypts the object streams whole, and leaves the Encrypt dictionary and the xref stream plain" do
      pdf = render(writer)

      expect(pdf).to include("/Filter /Standard")
      expect(xref_of(pdf)).to include("/Type /XRef").and include("/Encrypt ")
      expect(reader_for(pdf).info).to eq(Producer: "Stationery")
    end
  end
end
