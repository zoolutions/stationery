# frozen_string_literal: true

require_relative "spec_helper"
require "tmpdir"

RSpec.describe Stationery::Railtie do
  describe "render pdf:" do
    it "sends the document inline with its filename" do
      response = get("/pdf/document?filename=x.pdf")

      expect(response.status).to eq(200)
      expect(response.content_type).to eq("application/pdf")
      expect(response.headers["Content-Disposition"]).to start_with("inline").and include('filename="x.pdf"')
      expect(response.body).to start_with("%PDF")
    end

    it "omits the filename when none is given" do
      expect(get("/pdf/document").headers["Content-Disposition"]).to eq("inline")
    end

    it "honours disposition:" do
      expect(get("/pdf/attachment").headers["Content-Disposition"]).to start_with("attachment")
    end

    it "refuses anything that is not a document" do
      expect { get("/pdf/name") }.to raise_error(ArgumentError, /expects a Stationery::Document \(got String\)/)
    end
  end

  it "makes send_pdf available in controllers" do
    response = get("/pdf/helper")

    expect(response.headers["Content-Disposition"]).to include('filename="helper.pdf"')
    expect(response.body).to start_with("%PDF")
  end

  it "finalizes Stationery once the app has initialized" do
    expect(Stationery.font_paths).to be_frozen
    expect(Ractor.shareable?(Stationery.font_paths)).to be(true) if defined?(Ractor)
    expect(Stationery.instrumenter).to be(ActiveSupport::Notifications)
  end

  it "finalizes the document classes the app had loaded by then" do
    expect(BootedPdf.config).to be_frozen
    expect(Ractor.shareable?(BootedPdf.config)).to be(true) if defined?(Ractor)
    expect { BootedPdf.page(size: :a4) }.to raise_error(FrozenError)
  end

  it "boots with a document class whose settings cannot be made shareable, keeping those as they are" do
    expect(BootedDraftPdf.config).to be_frozen
    expect(BootedDraftPdf.config[:shaping][:shaper]).to be(BOOTED_SHAPER)
    expect(BOOTED_SHAPER).not_to be_frozen
    expect(BootedDraftPdf.new.to_pdf).to start_with("%PDF")
    expect(BOOTED_SHAPER.texts).to include("Booted", "Draft")
  end

  describe "initializers" do
    let(:root) { Dir.mktmpdir }
    let(:fonts) { File.join(root, "vendor/fonts") }

    # The app above has booted, and so finalized: each example adds its font
    # paths on a fresh boot of its own.
    around { |example| BootState.around(&example) }
    after { FileUtils.remove_entry(root) }

    def run_initializer(name, **config)
      options = ActiveSupport::OrderedOptions[config]
      app = Struct.new(:root, :config).new(Pathname(root), Struct.new(:stationery).new(options))
      described_class.instance.initializers.find { it.name == name }.run(app)
    end

    it "adds existing font directories under the app root" do
      FileUtils.mkdir_p(fonts)
      run_initializer("stationery.font_paths", font_paths: ["vendor/fonts", "missing"])
      run_initializer("stationery.font_paths", font_paths: ["vendor/fonts"])

      expect(Stationery.font_paths.count(fonts)).to eq(1)
      expect(Stationery.font_paths).not_to include(File.join(root, "missing"))
    end

    it "skips the renderer when disabled" do
      allow(ActiveSupport).to receive(:on_load)
      run_initializer("stationery.renderer", renderer: false)

      expect(ActiveSupport).not_to have_received(:on_load)
    end

    it "enables the renderer by default" do
      expect(described_class.config.stationery.to_h).to include(renderer: true)
    end
  end
end
