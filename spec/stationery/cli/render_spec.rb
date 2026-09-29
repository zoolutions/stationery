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

  it "counts the pages of a tagged document, packed into object streams" do
    target = File.join(dir, "tagged.pdf")

    expect(render(fixture("tagged.rb"), "--out", target)).to eq(0)
    expect(File.binread(target)).to include("/Type /ObjStm")
    expect(out.string).to start_with("wrote #{target} (2 pages, ")
  end

  it "counts the pages of an encrypted tagged document, whose object streams it cannot read" do
    target = File.join(dir, "encrypted.pdf")

    expect(render(fixture("encrypted_tagged.rb"), "--out", target)).to eq(0)
    expect(out.string).to start_with("wrote #{target} (2 pages, ")
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

  describe "--png" do
    def size_of(png) = png.byteslice(16, 8).unpack("NN")

    it "writes a picture of each page beside the PDF and says where" do
      target = File.join(dir, "inspected.pdf")

      expect(render(fixture("inspected.rb"), "--png", "--out", target)).to eq(0)
      pictures = [1, 2].map { |number| File.join(dir, "inspected-#{number}.png") }
      expect(File.binread(target)).to start_with("%PDF")
      expect(pictures.map { |path| size_of(File.binread(path)) }).to eq([[267, 214]] * 2)
      expect(out.string.lines.drop(1)).to eq(pictures.each_with_index.map do |path, index|
        "wrote #{path} (page #{index + 1}, 267 x 214 px)\n"
      end)
    end

    it "draws at --dpi" do
      expect(render(fixture("one.rb"), "--png", "--dpi", "144", "--out", File.join(dir, "one.pdf"))).to eq(0)
      expect(size_of(File.binread(File.join(dir, "one-1.png")))).to eq([400, 240])
    end

    it "draws the pages of --pages" do
      expect(render(fixture("inspected.rb"), "--png", "--pages", "2", "--out", File.join(dir, "x.pdf"))).to eq(0)
      expect(Dir.children(dir).sort).to eq(%w[x-2.png x.pdf])
    end

    it "writes the pictures without the PDF with --png-only" do
      expect(render(fixture("inspected.rb"), "--png-only", "--pages", "1-2", "--out", File.join(dir, "x.pdf"))).to eq(0)
      expect(Dir.children(dir).sort).to eq(%w[x-1.png x-2.png])
      expect(out.string.lines.size).to eq(2)
    end

    it "writes nothing under --strict when the render warns" do
      expect(render(fixture("overflow.rb"), "--png-only", "--strict", "--out", File.join(dir, "x.pdf"))).to eq(1)
      expect(Dir.children(dir)).to be_empty
    end

    it "fails for a page the document does not have" do
      expect(render(fixture("one.rb"), "--png-only", "--pages", "3", "--out", File.join(dir, "x.pdf"))).to eq(1)
      expect(err.string).to include("no page 3")
    end

    it "refuses --out - and a --pages it cannot read" do
      expect(render(fixture("one.rb"), "--png", "--out", "-")).to eq(2)
      expect(render(fixture("one.rb"), "--png", "--pages", "one")).to eq(2)
      expect(err.string).to include("--png writes files", "invalid argument: --pages one")
    end
  end

  describe "--zpl" do
    it "writes ZPL next to the source, at --dpi" do
      FileUtils.mkdir(File.join(dir, "cli"))
      FileUtils.cp(fixture("one.rb"), File.join(dir, "cli"))
      FileUtils.ln_s(File.expand_path("../../fixtures/fonts", __dir__), File.join(dir, "fonts"))
      target = File.join(dir, "cli/one.zpl")

      expect(render(File.join(dir, "cli/one.rb"), "--zpl", "--dpi", "300")).to eq(0)
      zpl = File.binread(target)
      expect(zpl).to start_with("^XA^PW834^LL500^").and(end_with("^XZ\n"))
      expect(out.string).to eq("wrote #{target} (1 label, #{zpl.bytesize} bytes)\n")
    end

    it "writes it to --out, and at 203 dpi by default" do
      target = File.join(dir, "one.zpl")

      expect(render(fixture("one.rb"), "--zpl", "--out", target)).to eq(0)
      expect(File.binread(target)).to start_with("^XA^PW564^LL339^")
    end

    it "writes no labels for a document that needs more pages than its max_pages" do
      target = File.join(dir, "two_labels.zpl")

      expect(render(fixture("two_labels.rb"), "--zpl", "--out", target)).to eq(1)
      expect(File.exist?(target)).to be(false)
      expect(err.string).to include('the document may have 1 page and needs 2: page 2 starts with "two"')
    end

    it "reports a resolution a ZPL printer does not have" do
      expect(render(fixture("one.rb"), "--zpl", "--dpi", "200", "--out", File.join(dir, "x.zpl"))).to eq(1)
      expect(err.string).to include("152, 203, 300 or 600")
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
    expect(out.string).to include("Usage: stationery render FILE", "--out", "--class", "--zpl", "--dpi", "--strict",
                                  "--debug")
  end
end
