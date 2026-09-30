# frozen_string_literal: true

require "stationery/verify"

RSpec.describe Stationery::Verify do
  let(:dir) { Dir.mktmpdir }
  let(:invoice) { File.join(dir, "invoice.pdf").tap { |path| RenderDigests.example("invoice").to_pdf(path) } }
  let(:clean) { ->(path) { { "file" => path, "pages" => [{ "number" => 1 }], "errors" => [], "warnings" => [] } } }

  after { FileUtils.rm_rf(dir) }

  it "is not loaded by require \"stationery\"" do
    expect(`#{RbConfig.ruby} -Ilib -rstationery -e 'print defined?(Stationery::Verify).inspect'`).to eq("nil")
  end

  it "answers an adapter for every engine, or for those named, and refuses a name that is not one" do
    expect(described_class.adapters.map(&:name)).to eq(%w[qpdf poppler mupdf pdfium pdfjs pdfkit])
    expect(described_class.adapters(%w[pdfjs qpdf]).map(&:class))
      .to eq([Stationery::Verify::Engines::Pdfjs, Stationery::Verify::Engines::Qpdf])
    expect { described_class.adapters(["acrobat"]) }.to raise_error(ArgumentError, /no engine acrobat/)
  end

  it "reads each file with each engine installed and holds it to the file, and lists those not installed" do
    report = described_class.run([invoice, invoice],
                                 engines: [FakeEngine.new("qpdf", true, clean), FakeEngine.new("mupdf", false)])

    found = report.results.map { |result| [result.file, result.engine, result.problems] }

    expect(found).to eq([[invoice, "qpdf", []], [invoice, "qpdf", []]])
    expect(report.missing.map(&:name)).to eq(["mupdf"])
    expect(report.passed?).to be(true)
  end

  it "hands the engines absolute paths, so none reads as an option, and reports the paths it was given" do
    seen = []
    Dir.chdir(dir) do
      File.binwrite("-o.pdf", File.binread(invoice))
      read = ->(path) { seen << path && clean.call(path) }

      expect(described_class.run(["-o.pdf"], engines: [FakeEngine.new("qpdf", true, read)]).results.map(&:file))
        .to eq(["-o.pdf"])
    end
    expect(seen).to eq([File.join(File.realpath(dir), "-o.pdf")])
  end

  it "fails a file an engine finds a problem in, and a run where no engine ran" do
    broken = ->(path) { clean.call(path).merge("errors" => ["cannot open"]) }

    expect(described_class.run([invoice], engines: [FakeEngine.new("qpdf", true, broken)]).passed?).to be(false)
    expect(described_class.run([invoice], engines: [FakeEngine.new("qpdf", false)]).passed?).to be(false)
  end

  it "holds a file pdf-reader cannot read to the engines opening it cleanly, and fails it" do
    File.binwrite(truncated = File.join(dir, "truncated.pdf"), File.binread(invoice).byteslice(0, 2000))
    report = described_class.run([truncated], engines: [FakeEngine.new("qpdf", true, clean)])

    expect(report.results.first.problems.first).to start_with("pdf-reader cannot read the file")
    expect(report.passed?).to be(false)
  end

  it "prints one line per file and engine, the problems under it, then the engines not run" do
    broken = ->(path) { clean.call(path).merge("warnings" => ["odd"]) }
    engines = [FakeEngine.new("qpdf", true, clean), FakeEngine.new("pdfjs", true, broken),
               FakeEngine.new("pdfkit", false)]

    expect(described_class.run([invoice], engines:).lines)
      .to eq([invoice, "  qpdf   ok  (qpdf 1.0)", "  pdfjs  FAILED  (pdfjs 1.0)", "      warning: odd",
              "not run: pdfkit (install pdfkit)"])
  end
end
