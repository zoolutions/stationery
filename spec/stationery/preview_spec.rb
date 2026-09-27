# frozen_string_literal: true

require "stationery/preview"

RSpec.describe Stationery::Preview do
  let(:document) { SpecDocument.build { text "hi" } }
  let(:preview) do
    doc = document
    Class.new(described_class) do
      define_method(:paid) { doc }
      define_method(:overdue) { |params| params[:document] }
      define_method(:name) { "not a document" }
    end
  end

  before { stub_const("ReceiptPdfPreview", preview) }

  describe ".all" do
    it "lists named subclasses with previews, sorted by name" do
      stub_const("AbstractPreview", Class.new(described_class))
      stub_const("AdmissionPreview", Class.new(described_class) { define_method(:ticket) { nil } })

      names = described_class.all.map(&:name)

      expect(names).to include("ReceiptPdfPreview", "AdmissionPreview")
      expect(names).not_to include("AbstractPreview", nil)
      expect(names.index("AdmissionPreview")).to be < names.index("ReceiptPdfPreview")
    end

    it "keeps only the latest class for a reloaded name" do
      reloaded = Class.new(described_class) { define_method(:paid) { nil } }
      stub_const("ReceiptPdfPreview", reloaded)

      expect(described_class.all.select { it.name == "ReceiptPdfPreview" }).to eq([reloaded])
    end
  end

  it "derives preview_name from the class name" do
    stub_const("Billing::HTTPInvoicePdfPreview", Class.new(described_class))

    expect(preview.preview_name).to eq("receipt_pdf")
    expect(Billing::HTTPInvoicePdfPreview.preview_name).to eq("billing/http_invoice_pdf")
  end

  it "lists its own public methods as pdfs" do
    expect(preview.pdfs).to eq(%w[name overdue paid])
  end

  it "does not list an around_render override as a pdf" do
    stub_const("WrappedPreview", Class.new(described_class) do
      def around_render(_name, _params) = yield
      def paid = nil
    end)

    expect(WrappedPreview.pdfs).to eq(%w[paid])
    expect(described_class.find("wrapped/around_render")).to be_nil
  end

  describe ".find" do
    it "returns the class and pdf for a path" do
      expect(described_class.find("receipt_pdf/paid")).to eq([preview, "paid"])
    end

    it "returns nil for unknown previews or pdfs" do
      expect(described_class.find("receipt_pdf/missing")).to be_nil
      expect(described_class.find("missing/paid")).to be_nil
      expect(described_class.find(nil)).to be_nil
    end
  end

  it "loads *_preview.rb files from the given paths" do
    described_class.load([File.expand_path("../fixtures/previews", __dir__), "/nonexistent"])

    klass, pdf = described_class.find("invoice_pdf/paid")
    expect(klass.new.render(pdf).to_pdf).to start_with("%PDF")
  end

  describe "#render" do
    it "returns the document" do
      expect(preview.new.render("paid")).to be(document)
    end

    it "passes params to methods that take them" do
      expect(preview.new.render("overdue", { document: })).to be(document)
    end

    it "refuses anything that is not a document" do
      expect { preview.new.render("name") }
        .to raise_error(Stationery::Error, "ReceiptPdfPreview#name must return a Stationery::Document (got String)")
    end
  end

  describe "#to_pdf" do
    let(:wrapped) do
      Class.new(described_class) do
        def around_render(_name, params)
          Thread.current[:preview_locale] = params.fetch("locale", "en")
          yield
        ensure
          Thread.current[:preview_locale] = nil
        end

        def greeting(_params)
          built = Thread.current[:preview_locale]
          SpecDocument.build { text "built #{built}, rendered #{Thread.current[:preview_locale]}" }
        end
      end
    end

    it "runs around_render around both building and rendering the document" do
      pdf = wrapped.new.to_pdf("greeting", { "locale" => "de" })

      expect(text_of(pdf)).to eq("built de, rendered de")
      expect(Thread.current[:preview_locale]).to be_nil
    end

    it "renders without a hook by default" do
      expect(preview.new.to_pdf("paid")).to start_with("%PDF")
    end

    it "passes debug: only to documents that accept it" do
      debuggable = Class.new(SpecDocument) { def to_pdf(debug: false) = "debug=#{debug}" }
      stub_const("DebugPreview", Class.new(described_class) { define_method(:paid) { debuggable.new } })

      expect(DebugPreview.new.to_pdf("paid", debug: true)).to eq("debug=true")
      expect(DebugPreview.new.to_pdf("paid")).to eq("debug=false")
      expect(preview.new.to_pdf("paid", debug: true)).to start_with("%PDF")
    end
  end
end
