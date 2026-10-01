# frozen_string_literal: true

require "fileutils"
require "json"
require "tmpdir"
require "stationery/cli"

RSpec.describe Stationery::CLI::Inspect do
  let(:out) { StringIO.new }
  let(:err) { StringIO.new }
  let(:dir) { Dir.mktmpdir }
  let(:pdf) do
    File.join(dir, "inspected.pdf").tap do |path|
      Stationery::CLI.start(["render", fixture("inspected.rb"), "--out", path], out: StringIO.new, err: StringIO.new)
    end
  end

  def fixture(name) = File.expand_path("../../fixtures/cli/#{name}", __dir__)
  def inspect_file(*argv) = Stationery::CLI.start(["inspect", *argv], out:, err:)

  after { FileUtils.rm_rf(dir) }

  it "is registered with the CLI" do
    expect(Stationery::CLI.commands).to include("inspect" => described_class)
  end

  describe "a PDF" do
    let(:lines) do
      raise "inspect failed: #{err.string}" unless inspect_file(pdf).zero?

      out.string.lines.map(&:rstrip)
    end

    it "starts with the file and what it says of itself" do
      expect(lines.first).to eq(pdf)
      expect(lines).to include(match(/\A  pages\s+2\z/), match(/\A  title\s+Inspected\z/),
                               match(/\A  lang\s+en\z/), match(/\A  print\s+copies: 2\z/))
      expect(out.string).not_to match(/date/i)
    end

    it "prints the outline with the page of each entry" do
      expect(lines.slice_after("Outline").to_a[1].first(2)).to eq(["  Start  page 1", "  End  page 2"])
    end

    it "prints each page: its size, then its text lines with x, y, font and size" do
      expect(lines).to include("Page 1  200 x 160 pt", "Page 2  200 x 160 pt")
      expect(lines).to include(match(/\A      10\.0 +\d+\.\d  OpenSans-Regular +10  Hello\z/))
      expect(lines.index { it.include?("Hello") }).to be < lines.index { it.include?("Visit") }
    end

    it "prints the images, links and fields with their rectangles" do
      expect(lines).to include(match(/\A      10\.0 +[\d.]+  20 x [\d.]+  \d+ x \d+ px\z/),
                               match(%r{\A      10\.0 +[\d.]+  [\d.]+ x [\d.]+  https://example\.com\z}),
                               match(/\A      10\.0 +[\d.]+  80 x [\d.]+  name  text  "Astrid"\z/),
                               match(/\A {6}10\.0 +[\d.]+  80 x [\d.]+  price  text  "9 kr"  center  auto  #DC2626\z/),
                               match(/\A {6}10\.0 +[\d.]+  80 x [\d.]+  qty  text  "2"  12 pt\z/))
      expect(lines).to include(start_with("  Images ("), start_with("  Links ("),
                               "  Fields (x, y, width x height, name, type, value, alignment, size, colour)")
    end

    it "says what each column is" do
      expect(lines).to include("  Text (x, baseline y, font, size, text)")
    end

    it "prints nothing it has not got" do
      expect(lines).not_to include("Structure", "Warnings", "  conformance")
    end
  end

  it "prints the same twice, so two renders diff cleanly" do
    inspect_file(pdf)
    first = out.string.dup
    out.truncate(0)
    out.rewind
    inspect_file(pdf)

    expect(out.string).to eq(first)
  end

  it "prints the layout as JSON with --json" do
    expect(inspect_file(pdf, "--json")).to eq(0)
    layout = JSON.parse(out.string)

    expect(layout["pages"].size).to eq(2)
    expect(layout["pages"][0]["text"][0]).to include("text" => "Hello", "font" => "OpenSans-Regular", "size" => 10.0)
    expect(layout["metadata"]).to include("title" => "Inspected")
    expect(layout["print"]).to eq("copies" => 2)
  end

  describe "a Ruby file" do
    it "renders the document and inspects it" do
      expect(inspect_file(fixture("inspected.rb"))).to eq(0)
      expect(out.string).to include("Page 2  200 x 160 pt", "The end")
      expect(File).not_to exist(fixture("inspected.pdf"))
    end

    it "prints the warnings of the render" do
      expect(inspect_file(fixture("overflow.rb"))).to eq(0)
      expect(out.string.lines.map(&:rstrip)).to include("Warnings")
      expect(out.string).to match(/^  content .*available/)
    end

    it "renders the one named by --class" do
      expect(inspect_file(fixture("two.rb"), "--class", "CliSecondDocument")).to eq(0)
      expect(out.string).to include("second")
    end
  end

  it "fails for a missing file" do
    expect(inspect_file(File.join(dir, "missing.pdf"))).to eq(1)
    expect(err.string).to include("no such file")
  end

  it "fails for a file that is neither a PDF nor Ruby" do
    path = File.join(dir, "notes.txt")
    File.write(path, "hello")

    expect(inspect_file(path)).to eq(1)
    expect(err.string).to include("not a PDF")
  end

  it "prints usage and exits 2 without a FILE" do
    expect(inspect_file).to eq(2)
    expect(err.string).to include("Usage: stationery inspect FILE")
  end

  it "prints its own help" do
    expect(inspect_file("--help")).to eq(0)
    expect(out.string).to include("Usage: stationery inspect FILE", "--json", "--class")
  end
end
