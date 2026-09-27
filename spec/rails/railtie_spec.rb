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

  describe "initializers" do
    let(:root) { Dir.mktmpdir }
    let(:fonts) { File.join(root, "vendor/fonts") }

    after do
      Stationery.font_paths.delete(fonts)
      FileUtils.remove_entry(root)
    end

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
