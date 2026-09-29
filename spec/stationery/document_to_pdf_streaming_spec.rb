# frozen_string_literal: true

require "stringio"

RSpec.describe Stationery::Document, "#to_pdf" do
  # Two renders carry the same dates only while time stands still.
  before { allow(Time).to receive(:now).and_return(Time.utc(2026, 1, 1, 12)) }

  let(:document) do
    Class.new(SpecDocument) do
      tagged
      # A block is handed an object stream a flush, the String one for every
      # 200 objects: the classic table keeps the two the same size.
      object_streams false
      metadata title: "Streamed", lang: "en"
      attach_file "notes.txt", "hello", mime: "text/plain"
      def view_template
        text "one"
        page_break
        text "two"
      end
    end.new
  end

  def streamed(doc, **)
    chunks = []
    count = doc.to_pdf(**) { |chunk| chunks << chunk.dup }
    [chunks.join, count, chunks]
  end

  def objects_of(pdf) = pdf.scan(/^(\d+) 0 obj/).flatten.map(&:to_i)

  it "returns the String and writes it to a path or an IO, in numbered object order" do
    pdf = document.to_pdf
    io = StringIO.new(+"".b)
    path = File.join(Dir.mktmpdir, "out.pdf")

    expect(document.to_pdf(io)).to eq(pdf)
    expect(io.string).to eq(pdf)
    expect(document.to_pdf(path)).to eq(pdf)
    expect(File.binread(path)).to eq(pdf)
    expect(objects_of(pdf)).to eq(objects_of(pdf).sort)
  end

  it "streams a valid file to a block: the same pages, text, fonts and objects as the String" do
    pdf = document.to_pdf
    file, count, chunks = streamed(document)

    expect(count).to eq(file.bytesize).and eq(pdf.bytesize)
    expect(chunks.size).to be > 1
    expect(objects_of(file)).to match_array(objects_of(pdf))
    expect(objects_of(file)).not_to eq(objects_of(file).sort)
    expect(reader_for(file).pages.map(&:text)).to eq(reader_for(pdf).pages.map(&:text)).and eq(%w[one two])
    expect(reader_for(file).pages.map { it.fonts.keys }).to eq(reader_for(pdf).pages.map { it.fonts.keys })
    expect(inspect_pdf(file).structure).to eq(inspect_pdf(pdf).structure)
    expect(inspect_pdf(file).attachments.first).to include(name: "notes.txt", bytes: "hello")
  end

  it "streams an encrypted document that opens with its password" do
    options = { encrypt: { user_password: "u", owner_password: "o" } }
    file, count, = streamed(document, **options)

    expect(count).to eq(document.to_pdf(**options).bytesize)
    reader = PDF::Reader.new(StringIO.new(file), password: "u")
    expect(reader.pages.map(&:text)).to eq(%w[one two])
  end

  it "writes a page's objects before the next page's and the shared ones last" do
    file, = streamed(document)

    expect(file.index("/Type /Catalog")).to be > file.rindex("/Type /Page ")
    expect(file.index("/Type /Pages")).to be > file.rindex("/Type /Page ")
  end

  it "hands a long document out in pieces, none more than a tenth of the file" do
    doc = Class.new(SpecDocument) do
      def view_template = 200.times { |n| text("page #{n}") && page_break }
    end.new
    largest = 0
    total = doc.to_pdf { |chunk| largest = [largest, chunk.bytesize].max }

    expect(total).to be > 40_000
    expect(largest).to be < total / 10
  end

  it "raises before the first chunk when strict finds warnings" do
    chunks = []
    doc = SpecDocument.build { text "☃" }

    expect { doc.to_pdf(strict: true) { chunks << it } }.to raise_error(Stationery::WarningsError)
    expect(chunks).to be_empty
  end

  it "refuses a block with a signature or with a target" do
    identity = SignatureHelpers.identity(:rsa)
    sign = { certificate: identity.certificate, key: identity.key }
    io = StringIO.new(+"".b)

    expect { document.to_pdf(sign:) { nil } }
      .to raise_error(ArgumentError, /signed document cannot be streamed to a block/)
    expect { document.to_pdf(io) { nil } }.to raise_error(ArgumentError, /target or a block, not both/)
    expect(inspect_pdf(document.to_pdf(io, sign:)).signatures.map { it[:valid] }).to eq([true])
    expect { Stationery::PDF::Assembler.new(pages: [], resources: nil, signature: :any, sink: :any) }
      .to raise_error(ArgumentError, /signed document cannot be streamed/)
  end
end
