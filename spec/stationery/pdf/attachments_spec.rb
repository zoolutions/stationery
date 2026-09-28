# frozen_string_literal: true

require "stringio"
require "zlib"

RSpec.describe Stationery::PDF::Attachments do
  let(:xml) { "<invoice>Müller &amp; Söhne</invoice>" }
  let(:document) { SpecDocument.build { text "Invoice" } }

  def catalog_of(pdf)
    objects = reader_for(pdf).objects
    objects.deref(objects.deref(objects.trailer[:Root]))
  end

  describe ".build" do
    it "normalises the pieces and defaults the type and relationship" do
      file = described_class.build("data.bin", "\x00\x01", description: "raw")

      expect(file.to_h).to include(name: "data.bin", mime: "application/octet-stream", description: "raw",
                                   relationship: :unspecified, modified_at: nil)
      expect(file.data.encoding).to eq(Encoding::BINARY)
    end

    it "refuses an empty name, non-String data and an unknown relationship" do
      expect { described_class.build("", "x") }.to raise_error(ArgumentError, "an attachment needs a name")
      expect { described_class.build("a", 1) }.to raise_error(ArgumentError, /"a" needs its data as a String/)
      expect { described_class.build("a", "x", relationship: :related) }
        .to raise_error(ArgumentError, /unknown attachment relationship :related; use one of :alternative/)
    end
  end

  describe ".merge" do
    it "combines attachments and hashes and rejects a name given twice" do
      first = described_class.build("a.txt", "a")

      merged = described_class.merge([first], [{ name: "b.txt", data: "b", mime: "text/plain" }])

      expect(merged.map(&:name)).to eq(%w[a.txt b.txt])
      expect(merged.last.mime).to eq("text/plain")
      expect { described_class.merge([first], [{ name: "a.txt", data: "again" }]) }
        .to raise_error(ArgumentError, 'attachment "a.txt" is given twice')
    end
  end

  it "writes a Filespec per file into the catalog's EmbeddedFiles name tree and /AF, sorted by name" do
    pdf = document.to_pdf(attachments: [
                            { name: "zeta.txt", data: "z" },
                            { name: "factur-x.xml", data: xml, mime: "text/xml", description: "Factur-X",
                              relationship: :alternative, modified_at: Time.utc(2026, 9, 28, 12, 0, 0) }
                          ])
    catalog = catalog_of(pdf)
    objects = reader_for(pdf).objects
    names = objects.deref(catalog.dig(:Names, :EmbeddedFiles))[:Names]

    expect(names.each_slice(2).map(&:first)).to eq(["factur-x.xml", "zeta.txt"])
    expect(catalog[:AF]).to eq(names.each_slice(2).map(&:last))

    spec = objects.deref(names[1])
    expect(spec).to include(Type: :Filespec, F: "factur-x.xml", UF: "factur-x.xml", Desc: "Factur-X",
                            AFRelationship: :Alternative)
    stream = objects.deref(spec[:EF][:F])
    expect(stream.hash).to include(Type: :EmbeddedFile, Subtype: :"text/xml", Filter: :FlateDecode)
    expect(stream.hash[:Params]).to include(Size: xml.bytesize, ModDate: "D:20260928120000Z")
    expect(stream.hash[:Params][:CheckSum]).to eq(Digest::MD5.digest(xml))
    expect(stream.unfiltered_data.force_encoding(Encoding::UTF_8)).to eq(xml)
    expect(pdf).to include("/Subtype /text#2Fxml")
  end

  it "takes class-level attach_file and merges per-render ones" do
    klass = Class.new(SpecDocument) do
      attach_file "a.txt", "class level", mime: "text/plain", relationship: :source
      def view_template = text("x")
    end

    files = inspect_pdf(klass.new.to_pdf(attachments: [{ name: "b.txt", data: "render" }])).attachments

    expect(files.map { |f| f.values_at(:name, :mime, :relationship) })
      .to eq([["a.txt", "text/plain", :source], ["b.txt", "application/octet-stream", :unspecified]])
    expect(files.map { |f| f[:bytes] }).to eq(["class level", "render"])
    expect { klass.new.to_pdf(attachments: [{ name: "a.txt", data: "again" }]) }
      .to raise_error(ArgumentError, 'attachment "a.txt" is given twice')
  end

  it "leaves a document without attachments byte-identical" do
    # Two renders a second apart differ by their dates and their file identifier.
    allow(Time).to receive(:now).and_return(Time.utc(2026, 9, 28, 12))
    plain = document.to_pdf
    expect(document.to_pdf(attachments: [])).to eq(plain)
    expect(plain).not_to include("EmbeddedFiles")
    expect(catalog_of(plain)).not_to have_key(:AF)
  end

  it "encrypts the embedded stream and decrypts it with the password" do
    pdf = document.to_pdf(encrypt: { user_password: "1234", owner_password: "s3cret" },
                          attachments: [{ name: "secret.txt", data: "top secret payload" }])
    raw = pdf[%r{/Type /EmbeddedFile.*?\nstream\n(.*?)\nendstream}m, 1]

    expect(raw).not_to include("top secret")
    expect { Zlib::Inflate.inflate(raw) }.to raise_error(Zlib::Error)

    reader = PDF::Reader.new(StringIO.new(pdf), password: "1234")
    objects = reader.objects
    names = objects.deref(objects.deref(objects.deref(objects.trailer[:Root])).dig(:Names, :EmbeddedFiles))[:Names]
    stream = objects.deref(objects.deref(names[1])[:EF][:F])
    expect(stream.unfiltered_data).to eq("top secret payload")
  end

  it "round-trips through the Inspector for an owner-only password" do
    pdf = document.to_pdf(encrypt: { owner_password: "s3cret" },
                          attachments: [{ name: "note.txt", data: "hello", mime: "text/plain" }])

    expect(inspect_pdf(pdf).attachments).to eq([{ name: "note.txt", mime: "text/plain", bytes: "hello",
                                                  description: nil, relationship: :unspecified }])
  end
end
