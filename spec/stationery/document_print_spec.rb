# frozen_string_literal: true

require "stringio"

RSpec.describe Stationery::Document do
  def body
    proc do
      3.times do |index|
        page_break unless index.zero?
        text "Label #{index + 1}"
      end
    end
  end
  let(:unhinted) do
    body = self.body
    Class.new(SpecDocument) { define_method(:view_template, &body) }
  end
  let(:label) do
    Class.new(unhinted) { print scaling: :none, copies: 2, pick_tray_by_size: true, duplex: :simplex }
  end

  def plain = SpecDocument.build { text "x" }

  def every_hint
    { scaling: :none, copies: 2, pick_tray_by_size: true, duplex: :long_edge, pages: [1..1, 3..3], dialog: :on_open }
  end

  def hints_of(pdf) = inspect_pdf(pdf).print_preferences

  def at(time = Time.utc(2026, 1, 1, 12))
    allow(Time).to receive(:now).and_return(time)
    yield
  end

  describe ".print" do
    it "writes the hints of the class to the catalog's /ViewerPreferences" do
      expect(catalog_of(label.new.to_pdf)[:ViewerPreferences])
        .to eq(PrintScaling: :None, NumCopies: 2, PickTrayByPDFSize: true, Duplex: :Simplex)
    end

    it "writes nothing without a hint: the file is what it was" do
      at do
        pdf = plain.to_pdf

        expect(catalog_of(pdf)).not_to include(:ViewerPreferences, :OpenAction)
        expect(plain.to_pdf(print: {})).to eq(pdf)
        expect(plain.to_pdf(print: nil)).to eq(pdf)
        expect(label.new.to_pdf(print: false)).to eq(unhinted.new.to_pdf)
      end
    end

    it "is inherited, and a subclass adds to it or takes a hint away" do
      more = Class.new(label) { print copies: 3, pages: 1..2 }
      less = Class.new(label) { print copies: nil, duplex: nil }

      expect(hints_of(more.new.to_pdf))
        .to eq(scaling: :none, copies: 3, pick_tray_by_size: true, duplex: :simplex, pages: [1..2])
      expect(hints_of(less.new.to_pdf)).to eq(scaling: :none, pick_tray_by_size: true)
      expect(hints_of(label.new.to_pdf)).to include(copies: 2, duplex: :simplex)
    end

    it "refuses what it cannot write where it is declared" do
      expect { Class.new(SpecDocument) { print scaling: :fit } }
        .to raise_error(ArgumentError, "print scaling: is :none or :default, not :fit")
      expect { Class.new(SpecDocument) { print colour: :red } }.to raise_error(ArgumentError, /unknown print hint/)
    end

    it "leaves Kernel#print to the instances" do
      expect(label.new.method(:print).owner).to eq(Kernel)
      expect(label.method(:print).owner).to eq(described_class.singleton_class)
    end
  end

  describe "#to_pdf(print:)" do
    it "lays its hints over the class's" do
      expect(hints_of(label.new.to_pdf(print: { copies: 1, pages: 2.. })))
        .to eq(scaling: :none, copies: 1, pick_tray_by_size: true, duplex: :simplex, pages: [2..3])
      expect(hints_of(plain.to_pdf(print: { scaling: :default }))).to eq(scaling: :default)
    end

    it "takes one hint away with nil, and all of them with print: nil or false" do
      expect(hints_of(label.new.to_pdf(print: { copies: nil }))).not_to have_key(:copies)
      expect(hints_of(label.new.to_pdf(print: nil))).to eq({})
      expect(hints_of(label.new.to_pdf(print: false))).to eq({})
    end

    it "refuses what it cannot write before anything is rendered" do
      doc = label.new

      expect { doc.to_pdf(print: { copies: 0 }) }
        .to raise_error(ArgumentError, "print copies: is an Integer of 1 or more, not 0")
      expect(doc.warnings).to be_nil
    end

    it "cuts the page ranges at the last page" do
      expect(hints_of(label.new.to_pdf(print: { pages: [1..1, 3..9] }))).to include(pages: [1..1, 3..3])
      expect(hints_of(label.new.to_pdf(print: { pages: 4..9 }))).not_to have_key(:pages)
    end

    it "opens the print dialog with dialog: :on_open" do
      pdf = plain.to_pdf(print: { dialog: :on_open })

      expect(catalog_of(pdf)[:OpenAction]).to eq(Type: :Action, S: :Named, N: :Print)
      expect(catalog_of(pdf)).not_to have_key(:ViewerPreferences)
    end

    it "keeps /DisplayDocTitle of a tagged document" do
      titled = Class.new(label) { metadata title: "Labels", lang: "en" }

      expect(catalog_of(titled.new.to_pdf(tagged: true))[:ViewerPreferences])
        .to eq(DisplayDocTitle: true, PrintScaling: :None, NumCopies: 2, PickTrayByPDFSize: true, Duplex: :Simplex)
    end
  end

  describe "every path that writes the catalog" do
    def expected = every_hint

    it "writes the hints of an incremental render, to a String and to a block" do
      chunks = []
      label.new.to_pdf(incremental: true, print: every_hint) { |chunk| chunks << chunk.dup }

      expect(hints_of(label.new.to_pdf(incremental: true, print: every_hint))).to eq(expected)
      expect(hints_of(chunks.join)).to eq(expected)
    end

    it "writes the hints of a signed document, and the signature holds" do
      identity = signer
      pdf = label.new.to_pdf(print: every_hint, sign: { certificate: identity.certificate, key: identity.key })

      expect(hints_of(pdf)).to eq(expected)
      expect(inspect_pdf(pdf).signatures.map { it[:valid] }).to eq([true])
    end

    it "writes the hints of an encrypted document, incremental or not" do
      encrypt = { user_password: "u", owner_password: "o" }

      [{}, { incremental: true }].each do |options|
        pdf = label.new.to_pdf(print: every_hint, encrypt:, **options)
        objects = PDF::Reader.new(StringIO.new(pdf), password: "u").objects
        catalog = objects.deref!(objects.trailer[:Root])

        expect(Stationery::PDF::PrintHints.read(catalog)).to eq(expected)
      end
    end
  end

  describe "with conformance" do
    let(:archived) do
      Class.new(label) { metadata title: "Labels", lang: "en" }
    end

    it "keeps the hints of /ViewerPreferences under PDF/A and PDF/UA" do
      pdf = archived.new.to_pdf(conformance: %i[pdf_a3b pdf_ua1], print: { pages: 1..2 })

      expect(pdf).to have_conformance(:pdf_a3b, :pdf_ua1)
      expect(hints_of(pdf)).to eq(scaling: :none, copies: 2, pick_tray_by_size: true, duplex: :simplex, pages: [1..2])
    end

    it "refuses the print dialog under PDF/A, which has no /Print action" do
      %i[pdf_a2b pdf_a3b].each do |level|
        expect { archived.new.to_pdf(conformance: level, print: { dialog: :on_open }) }
          .to raise_error(Stationery::ConformanceError, /print dialog: :on_open.*6\.5\.1/)
      end
    end

    it "opens the print dialog under PDF/UA-1" do
      pdf = archived.new.to_pdf(conformance: :pdf_ua1, print: { dialog: :on_open })

      expect(hints_of(pdf)).to include(dialog: :on_open)
    end
  end
end
