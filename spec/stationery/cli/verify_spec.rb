# frozen_string_literal: true

require "fileutils"
require "json"
require "tmpdir"
require "stationery/cli"
require "stationery/verify"

RSpec.describe Stationery::CLI::Verify do
  let(:out) { StringIO.new }
  let(:err) { StringIO.new }
  let(:dir) { Dir.mktmpdir }
  let(:pdf) { File.join(dir, "inspected.pdf").tap { |path| File.binwrite(path, inspected.to_pdf) } }
  # A clean read of the two pages of the fixture.
  let(:engines) do
    pages = [{ "number" => 1 }, { "number" => 2 }]
    clean = ->(path) { { "file" => path, "pages" => pages, "errors" => [], "warnings" => [] } }
    [FakeEngine.new("qpdf", true, clean), FakeEngine.new("pdfjs", true, clean), FakeEngine.new("pdfkit", false)]
  end

  def fixture(name) = File.expand_path("../../fixtures/cli/#{name}", __dir__)

  def inspected
    require fixture("inspected.rb")
    CliInspectedDocument.new
  end

  def verify(*argv) = Stationery::CLI.start(["verify", *argv], out:, err:)

  before { allow(Stationery::Verify).to receive(:adapters) { |names = nil| names ? engines.select { names.include?(it.name) } : engines } }
  after { FileUtils.rm_rf(dir) }

  it "is registered with the CLI" do
    expect(Stationery::CLI.commands).to include("verify" => described_class)
  end

  it "passes a file every available engine reads cleanly, and says which engines did not run" do
    expect(verify(pdf)).to eq(0)
    expect(out.string.lines.map(&:rstrip)).to eq([pdf, "  qpdf   ok  (qpdf 1.0)", "  pdfjs  ok  (pdfjs 1.0)",
                                                  "not run: pdfkit (install pdfkit)"])
  end

  it "fails a file an engine finds a problem in, with the problem" do
    clean = engines[1].read
    engines[1].read = ->(path) { clean.call(path).merge("warnings" => ["Warning: something"]) }

    expect(verify(pdf)).to eq(1)
    expect(out.string).to include("  pdfjs  FAILED  (pdfjs 1.0)\n      warning: Warning: something")
  end

  it "runs the engines --engines names, and fails when one of them is not installed" do
    expect(verify(pdf, "--engines", "pdfjs")).to eq(0)
    expect(out.string).not_to include("qpdf")

    expect(verify(pdf, "--engines", "qpdf,pdfkit")).to eq(1)
    expect(err.string).to include("not installed: pdfkit (install pdfkit)")
  end

  it "fails when no engine is installed" do
    engines.each { it.available = false }

    expect(verify(pdf)).to eq(1)
    expect(err.string).to include("no engine is installed", "install qpdf")
  end

  it "prints usage and exits 2 for an engine that does not exist" do
    allow(Stationery::Verify).to receive(:adapters).and_call_original

    expect(verify(pdf, "--engines", "acrobat")).to eq(2)
    expect(err.string).to include("no engine acrobat")
  end

  it "hands --password to the engines and to pdf-reader" do
    File.binwrite(pdf, inspected.to_pdf(encrypt: { user_password: "secret", owner_password: "owner" }))

    expect(verify(pdf, "--password", "secret")).to eq(0)
    expect(engines.first.passwords).to eq(["secret"])
  end

  it "prints the report as JSON with --json" do
    expect(verify(pdf, "--json")).to eq(0)
    report = JSON.parse(out.string)

    expect(report).to include("passed" => true, "missing" => [{ "engine" => "pdfkit", "install" => "install pdfkit" }])
    expect(report["results"].map { it["engine"] }).to eq(%w[qpdf pdfjs])
  end

  it "renders a Ruby file first and verifies what it wrote" do
    expect(verify(fixture("inspected.rb"))).to eq(0)
    expect(out.string).to include("inspected.rb", "qpdf   ok")
    expect(File).not_to exist(fixture("inspected.pdf"))
  end

  it "fails for a missing file or one that is not a PDF" do
    expect(verify(File.join(dir, "missing.pdf"))).to eq(1)
    expect(err.string).to include("no such file")

    File.write(notes = File.join(dir, "notes.txt"), "hello")
    expect(verify(notes)).to eq(1)
    expect(err.string).to include("not a PDF")
  end

  it "prints usage and exits 2 without a FILE, and its own help" do
    expect(verify).to eq(2)
    expect(err.string).to include("Usage: stationery verify FILE")

    expect(verify("--help")).to eq(0)
    expect(out.string).to include("--engines", "--password", "--json")
  end
end
