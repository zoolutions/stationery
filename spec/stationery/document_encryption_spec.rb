# frozen_string_literal: true

require "stringio"
require "zlib"

RSpec.describe Stationery::Document do
  let(:options) { { user_password: "1234", owner_password: "s3cret" } }

  def document
    image = image_path("rgb.jpg")
    SpecDocument.build do
      text "Encrypted Müller"
      image image, width: 20
    end
  end

  def open_pdf(pdf, password = "") = PDF::Reader.new(StringIO.new(pdf), password:)
  def text_with(pdf, password) = open_pdf(pdf, password).pages.map(&:text).join

  def raw_stream(pdf, id)
    pdf[/^#{id} 0 obj\n.*?\nstream\n(.*?)\nendstream/m, 1]
  end

  def stream_id(pdf, password)
    open_pdf(pdf, password).objects.each do |ref, object|
      return ref.id if object.is_a?(PDF::Reader::Stream) && yield(object.hash)
    end
    nil
  end

  %i[aes_256 aes_128 rc4_128].each do |algorithm|
    context "with #{algorithm}" do
      let(:pdf) { document.to_pdf(encrypt: options.merge(algorithm:)) }

      it "opens with the user or the owner password and extracts the text" do
        expect(text_with(pdf, "1234")).to include("Encrypted Müller")
        expect(text_with(pdf, "s3cret")).to include("Encrypted Müller")
        expect(open_pdf(pdf, "s3cret").info).to include(Producer: /Stationery/)
      end

      it "refuses a wrong password" do
        expect { open_pdf(pdf, "nope").pages.first.text }.to raise_error(PDF::Reader::EncryptedPDFError)
      end

      it "encrypts image, font and content streams and the document info" do
        image = raw_stream(pdf, stream_id(pdf, "1234") { |dict| dict[:Subtype] == :Image })
        font = raw_stream(pdf, stream_id(pdf, "1234") { |dict| dict.key?(:Length1) })

        expect(image).not_to start_with("\xFF\xD8".b)
        expect { Zlib::Inflate.inflate(font) }.to raise_error(Zlib::Error)
        expect(pdf).not_to include("Stationery #{Stationery::VERSION}")
      end

      it "writes the same file ID in both trailer slots and references the Encrypt dictionary" do
        trailer = pdf[/trailer\n.*/m]
        ids = trailer.scan(/<(\h{32})>/).flatten

        expect(ids.size).to eq(2)
        expect(ids.uniq.size).to eq(1)
        expect(trailer).to match(%r{/Encrypt \d+ 0 R})
      end
    end
  end

  it "opens without a password when the user password is omitted and records the permissions" do
    pdf = document.to_pdf(encrypt: { owner_password: "s3cret", permissions: [:print] })
    objects = open_pdf(pdf).objects

    expect(text_with(pdf, "")).to include("Encrypted Müller")
    expect(objects.deref(objects.trailer[:Encrypt])[:P]).to eq(-3900)
  end

  it "requires an owner password" do
    expect { document.to_pdf(encrypt: { user_password: "1234" }) }.to raise_error(ArgumentError, /owner_password/)
    expect { document.to_pdf(encrypt: { owner_password: "" }) }.to raise_error(ArgumentError, /owner_password/)
  end

  describe ".encrypt" do
    let(:klass) do
      Class.new(SpecDocument) do
        encrypt owner_password: "s3cret", permissions: [:print]
        def view_template = text("Locked")
      end
    end

    it "encrypts every render by default" do
      pdf = klass.new.to_pdf

      expect(pdf).to match(%r{/Encrypt \d+ 0 R})
      expect(text_with(pdf, "")).to include("Locked")
    end

    it "renders plain with encrypt: nil and honours an override" do
      override = klass.new.to_pdf(encrypt: { user_password: "x", owner_password: "y" })

      expect(klass.new.to_pdf(encrypt: nil)).not_to include("/Encrypt")
      expect(text_with(override, "x")).to include("Locked")
      expect { text_with(override, "") }.to raise_error(PDF::Reader::EncryptedPDFError)
    end

    it "validates the options when the class is defined" do
      expect { Class.new(SpecDocument) { encrypt user_password: "1234" } }.to raise_error(ArgumentError)
    end
  end
end
