# frozen_string_literal: true

require "stationery/cli"

RSpec.describe Stationery::CLI::Examples do
  let(:out) { StringIO.new }
  let(:err) { StringIO.new }
  let(:dir) { File.expand_path("../../../examples", __dir__) }

  def examples(*argv) = Stationery::CLI.start(["examples", *argv], out:, err:)

  it "is registered with the CLI" do
    expect(Stationery::CLI.commands).to include("examples" => described_class)
  end

  it "lists every example with what it shows, in one line each" do
    expect(examples).to eq(0)

    lines = out.string.lines.map(&:chomp)
    names = Dir.glob("**/*.rb", base: dir).map { it.delete_suffix(".rb") }.sort
    expect(lines.take(names.size).map { it.split.first }).to eq(names)
    expect(lines.grep(/\Areport\s/).first).to match(/\Areport\s+A multi-page annual report: cover, contents/)
    expect(lines.grep(%r{\Ashaping/harfbuzz_shaper\s}).first).to include("A shaper for Stationery::Shaper")
    expect(lines.take(names.size)).to all(match(/\A\S+\s+\S.*[^:]\z/))
    expect(out.string).not_to include("Run it")
    expect(out.string).to include(dir)
  end

  it "prints the path of one example" do
    expect(examples("invoice")).to eq(0)
    expect(out.string).to eq("#{File.join(dir, "invoice.rb")}\n")
  end

  it "takes the name with its extension, and an example in a directory" do
    expect(examples("invoice.rb")).to eq(0)
    expect(examples("shaping/harfbuzz_shaper")).to eq(0)
    expect(out.string.lines.map(&:chomp))
      .to eq([File.join(dir, "invoice.rb"), File.join(dir, "shaping/harfbuzz_shaper.rb")])
  end

  it "prints the source of one example with --source" do
    expect(examples("letter", "--source")).to eq(0)
    expect(out.string).to eq(File.read(File.join(dir, "letter.rb")))
  end

  it "fails with exit 1 for a name that is not an example" do
    expect(examples("missing")).to eq(1)
    expect(examples("../lib/stationery")).to eq(1)
    expect(err.string).to include('stationery: no example named "missing"', "report")
    expect(out.string).to be_empty
  end

  it "prints help" do
    expect(examples("--help")).to eq(0)
    expect(out.string).to include("Usage: stationery examples [NAME]", "--source")
  end

  it "rejects unknown options" do
    expect(examples("--nope")).to eq(2)
    expect(err.string).to include("invalid option: --nope", "Usage: stationery examples")
  end
end
