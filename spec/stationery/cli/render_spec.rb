# frozen_string_literal: true

require "fileutils"
require "tmpdir"
require "stationery/cli"

RSpec.describe Stationery::CLI::Render do
  let(:out) { StringIO.new }
  let(:err) { StringIO.new }
  let(:dir) { Dir.mktmpdir }

  def fixture(name) = File.expand_path("../../fixtures/cli/#{name}", __dir__)
  def render(*argv) = Stationery::CLI.start(["render", *argv], out:, err:)

  after { FileUtils.rm_rf(dir) }

  it "renders the document to --out and reports pages and bytes" do
    target = File.join(dir, "one.pdf")

    expect(render(fixture("one.rb"), "--out", target)).to eq(0)
    pdf = File.binread(target)
    expect(text_of(pdf)).to eq("one")
    expect(out.string).to eq("wrote #{target} (1 page, #{pdf.bytesize} bytes)\n")
    expect(err.string).to be_empty
  end

  it "writes next to the source by default" do
    FileUtils.mkdir(File.join(dir, "cli"))
    FileUtils.cp(fixture("one.rb"), File.join(dir, "cli"))
    FileUtils.ln_s(File.expand_path("../../fixtures/fonts", __dir__), File.join(dir, "fonts"))

    expect(render(File.join(dir, "cli/one.rb"))).to eq(0)
    expect(File.binread(File.join(dir, "cli/one.pdf"))).to start_with("%PDF")
  end

  it "writes the PDF to out for --out -" do
    expect(render(fixture("one.rb"), "--out", "-")).to eq(0)
    expect(out.string).to start_with("%PDF").and(end_with("%%EOF\n"))
    expect(out.string.encoding).to eq(Encoding::BINARY)
  end

  it "counts every page" do
    target = File.join(dir, "overflow.pdf")

    render(fixture("overflow.rb"), "-o", target)
    expect(out.string).to match(/\(\d+ pages?, \d+ bytes\)/)
    expect(out.string[/(\d+) page/, 1].to_i).to eq(page_count(File.binread(target)))
  end

  it "renders the document the file defines, not the one it requires and extends" do
    target = File.join(dir, "extended.pdf")

    expect(render(fixture("extends.rb"), "--out", target)).to eq(0)
    expect(inspect_pdf(File.binread(target)).metadata[:Title]).to eq("Extended")
    expect(err.string).to be_empty
  end

  context "with several documents in the file" do
    it "refuses to guess and lists them" do
      expect(render(fixture("two.rb"), "--out", File.join(dir, "x.pdf"))).to eq(1)
      expect(err.string).to include("several documents", "CliFirstDocument", "CliSecondDocument", "--class")
    end

    it "renders the one named by --class" do
      target = File.join(dir, "second.pdf")

      expect(render(fixture("two.rb"), "--class", "CliSecondDocument", "--out", target)).to eq(0)
      expect(text_of(File.binread(target))).to eq("second")
    end
  end

  it "rejects a --class that is not a document" do
    expect(render(fixture("one.rb"), "--class", "String")).to eq(1)
    expect(err.string).to include("String is not a Stationery::Document")
  end

  it "rejects an unknown --class" do
    expect(render(fixture("one.rb"), "--class", "NoSuchDocument")).to eq(1)
    expect(err.string).to include("uninitialized constant NoSuchDocument")
  end

  it "fails when the file defines no document" do
    expect(render(fixture("empty.rb"))).to eq(1)
    expect(err.string).to include("no Stationery::Document defined in #{fixture("empty.rb")}")
  end

  it "explains how to render a document that needs arguments" do
    expect(render(fixture("needs_args.rb"))).to eq(1)
    expect(err.string).to include("CliNeedsArgsDocument needs arguments; define `def self.preview`")
  end

  context "when the document overflows" do
    let(:target) { File.join(dir, "overflow.pdf") }

    it "prints the warnings and still writes" do
      expect(render(fixture("overflow.rb"), "--out", target)).to eq(0)
      expect(err.string).to include("warning: content", "available")
      expect(File).to exist(target)
    end

    it "fails under --strict without writing" do
      expect(render(fixture("overflow.rb"), "--strict", "--out", target)).to eq(1)
      expect(err.string).to include("warning: content", "--strict")
      expect(File).not_to exist(target)
    end
  end

  describe "--debug" do
    it "passes debug: true when to_pdf accepts it" do
      target = File.join(dir, "debug.pdf")

      expect(render(fixture("debug.rb"), "--debug", "--out", target)).to eq(0)
      expect(text_of(File.binread(target))).to eq("debug on")
    end

    it "renders without it and says so when to_pdf does not accept it" do
      target = File.join(dir, "plain.pdf")

      expect(render(fixture("no_debug.rb"), "--debug", "--out", target)).to eq(0)
      expect(err.string).to include("--debug is not supported")
      expect(text_of(File.binread(target))).to eq("plain")
    end
  end

  it "prints usage and exits 2 without a FILE" do
    expect(render).to eq(2)
    expect(err.string).to include("Usage: stationery render FILE")
  end

  it "prints usage and exits 2 for an unknown option" do
    expect(render(fixture("one.rb"), "--nope")).to eq(2)
    expect(err.string).to include("invalid option: --nope", "Usage: stationery render FILE")
  end

  it "prints its own help" do
    expect(render("--help")).to eq(0)
    expect(out.string).to include("Usage: stationery render FILE", "--out", "--class", "--strict", "--debug")
  end
end
