# frozen_string_literal: true

require "stationery/verify"

RSpec.describe Stationery::Verify::Engines do
  let(:dir) { Dir.mktmpdir }
  let(:invoice) { File.join(dir, "invoice.pdf").tap { |path| RenderDigests.example("invoice").to_pdf(path) } }

  def ran(stdout: "", stderr: "", exitstatus: 0)
    status = instance_double(Process::Status, success?: exitstatus.zero?, exitstatus:)
    Stationery::Verify::Command::Result.new(stdout:, stderr:, status:, timed_out: false)
  end

  after { FileUtils.rm_rf(dir) }

  # Each engine on a real file, where it is installed: CI's conformance
  # and readers-macos jobs have them.
  Stationery::Verify::ENGINES.each do |name, engine|
    describe engine do
      it "reads the invoice example with nothing wrong, and names its version" do
        adapter = engine.new
        skip "#{name} is not installed (#{adapter.install})" unless adapter.available?

        facts = adapter.facts([invoice]).first
        expectation = Stationery::Verify::Expectation.read(Stationery::Testing::Inspector.new(Pathname(invoice)))

        expect(Stationery::Verify::Comparison.new(expectation, facts, engine: name).problems).to eq([])
        expect(adapter.version).to match(/\d/)
      end
    end
  end

  describe Stationery::Verify::Engines::Qpdf do
    it "fails what --check calls an error, and warns what it calls a warning" do
      allow(Stationery::Verify::Command).to receive(:run) do |*argv, **|
        next ran(stdout: "2\n") if argv.include?("--show-npages")

        ran(stderr: "WARNING: file.pdf: object 3 0: stream length wrong\n", exitstatus: 3)
      end

      expect(described_class.new.facts(["file.pdf"]).first)
        .to include("pages" => [{ "number" => 1 }, { "number" => 2 }], "errors" => [],
                    "warnings" => ["WARNING: file.pdf: object 3 0: stream length wrong"])
    end

    it "hands a password through a file only it can read" do
      seen = []
      allow(Stationery::Verify::Command).to receive(:run) do |*argv, **|
        file = argv.find { it.start_with?("--password-file=") }.delete_prefix("--password-file=")
        seen << [File.read(file), File.stat(file).mode & 0o777]
        ran(stdout: "1\n")
      end

      described_class.new.facts(["file.pdf"], password: "secret")
      expect(seen.uniq).to eq([["secret", 0o600]])
    end
  end

  describe Stationery::Verify::Engines::Poppler do
    let(:signed) do
      <<~PDFSIG
        Digital Signature Info of: file.pdf
        Signature #1:
          - Signature Field Name: signature
          - Total document signed
          - Signature Validation: Signature is Valid.
        Signature #2:
          - Signature Field Name: witness
          The signature form field is not signed.
      PDFSIG
    end

    it "reads the fonts, attachments and signed signatures, and fails a stderr line" do
      outputs = { "pdfinfo" => ran(stdout: "Pages:          1\n"), "pdftotext" => ran(stdout: "Hello\f"),
                  "pdffonts" => ran(stdout: <<~FONTS),
                    name                                 type              encoding         emb sub uni object ID
                    ------------------------------------ ----------------- ---------------- --- --- --- ---------
                    ABCDEF+Inter-Regular                 CID TrueType      Identity-H       yes yes no       7  0
                    Helvetica                            Type 1            WinAnsi          no  no  no       9  0
                  FONTS
                  "pdfdetach" => ran(stdout: "1 embedded files\n1: factur-x.xml\n"),
                  "pdfsig" => ran(stdout: signed, stderr: "Syntax Warning: odd\n") }
      allow(Stationery::Verify::Command).to receive(:run) { |tool, *| outputs.fetch(tool, ran) }

      facts = described_class.new.facts(["file.pdf"]).first

      expect(facts).to include("fonts" => [{ "name" => "ABCDEF+Inter-Regular", "embedded" => true, "unicode" => false },
                                           { "name" => "Helvetica", "embedded" => false, "unicode" => false }],
                               "attachments" => ["factur-x.xml"], "signatures" => { "count" => 1, "valid" => true },
                               "errors" => [], "warnings" => ["Syntax Warning: odd"])
      expect(facts["pages"]).to eq([{ "number" => 1, "text" => "Hello", "painted" => nil }])
    end

    it "reads a file without signatures as none, and leaves them out for a password" do
      outputs = { "pdfsig" => ran(stdout: "File 'file.pdf' does not contain any signatures\n", exitstatus: 2) }
      allow(Stationery::Verify::Command).to receive(:run) { |tool, *| outputs.fetch(tool, ran) }

      expect(described_class.new.facts(["file.pdf"]).first).to include("signatures" => { "count" => 0, "valid" => nil },
                                                                       "errors" => [])
      expect(described_class.new.facts(["file.pdf"], password: "secret").first).to include("signatures" => nil)
    end
  end

  describe Stationery::Verify::Engine do
    it "fails each file a script did not answer for, with why it stopped" do
      allow(Stationery::Verify::Command).to receive(:run)
        .and_return(ran(stdout: %({"file":"a.pdf","pages":[],"errors":[],"warnings":[]}\n), stderr: "Traceback\nBoom\n",
                        exitstatus: 1))

      facts = Stationery::Verify::Engines::Pdfium.new.facts(%w[a.pdf b.pdf])

      python = ENV.fetch("STATIONERY_PYTHON", "python3")
      expect(facts.map { |read| read["errors"] }).to eq([[], ["#{python} exited 1: Traceback: Boom"]])
    end

    it "fails a file whose line of facts is not JSON, and reads the others" do
      allow(Stationery::Verify::Command).to receive(:run)
        .and_return(ran(stdout: %({"file":"a.pdf","pages":[],"errors":[],"warnings":[]}\n{"file":"b.pdf",\n)))

      facts = Stationery::Verify::Engines::Pdfium.new.facts(%w[a.pdf b.pdf])

      expect(facts.map { |read| read["errors"].size }).to eq([0, 1])
    end

    it "runs Python isolated, so no module is loaded from the working directory" do
      allow(Stationery::Verify::Command).to receive(:run).and_return(ran)
      Stationery::Verify::Engines::Pdfium.new.facts(%w[a.pdf])

      expect(Stationery::Verify::Command).to have_received(:run).with(anything, "-I", anything, "a.pdf", any_args)
    end

    it "calls a grey picture painted when a pixel is not white" do
      engine = described_class.new

      expect(engine.send(:painted?, "P5\n2 1\n255\n\xFF\xFF".b)).to be(false)
      expect(engine.send(:painted?, "P5\n2 1\n255\n\xFF\x80".b)).to be(true)
    end
  end
end
