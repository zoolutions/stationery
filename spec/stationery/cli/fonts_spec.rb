# frozen_string_literal: true

require "fileutils"
require "tmpdir"
require "stationery/cli"

RSpec.describe Stationery::CLI::Fonts do
  let(:out) { StringIO.new }
  let(:err) { StringIO.new }
  let(:dir) { Dir.mktmpdir }
  let(:requests) { [] }

  def fonts(*argv) = Stationery::CLI.start(["fonts", *argv], out:, err:)

  before do
    fetcher = lambda do |url|
      requests << url
      "not a font"
    end
    allow(Stationery::Fonts::Installer).to receive(:new).and_wrap_original do |original, **options|
      original.call(**options, fetcher:)
    end
  end

  after { FileUtils.rm_rf(dir) }

  it "is registered with the CLI" do
    expect(Stationery::CLI.commands).to include("fonts" => described_class)
  end

  it "lists every pack with its family, license and whether it is installed" do
    FileUtils.mkdir_p(File.join(dir, "inter"))
    FileUtils.cp(File.join(Stationery::Fonts::Bundled::DIR, "Inter-Regular.ttf"), File.join(dir, "inter"))

    expect(fonts("list", "--into", dir)).to eq(0)
    lines = out.string.lines
    expect(lines.grep(/\Ainter\s/).first).to include("Inter", "OFL-1.1", "installed")
    expect(lines.grep(/\Anoto_sans\s/).first).to include("Noto Sans", "-")
    expect(lines.grep(/\Aliberation_mono\s/).first).to include("Liberation Mono")
    expect(out.string).to include("Reserved Font Name", "unmodified")
  end

  it "installs packs --into a directory and prints how to use them" do
    expect(fonts("install", "inter", "--into", dir)).to eq(0)
    expect(File).to exist(File.join(dir, "inter/Inter-BoldItalic.ttf"))
    expect(out.string).to include("wrote #{File.join(dir, "inter/Inter-Regular.ttf")}",
                                  "font_family \"Inter\", **Stationery::Fonts.paths(:inter, dir: \"#{dir}\")")
    expect(Stationery::Fonts::Installer).to have_received(:new).with(into: dir, force: false, from: nil, out:)
  end

  it "passes --force and --from through" do
    fonts("install", "inter", "--into", dir, "--force", "--from", dir)

    expect(Stationery::Fonts::Installer).to have_received(:new).with(into: dir, force: true, from: dir, out:)
  end

  it "fails with exit 1 on a SHA-256 mismatch, writing nothing" do
    expect(fonts("install", "noto_sans", "--into", dir)).to eq(1)
    expect(err.string).to include("stationery: SHA-256 mismatch for NotoSans-Regular.ttf")
    expect(requests).not_to be_empty
    expect(Dir.children(dir)).to be_empty
  end

  it "fails with exit 1 for an unknown pack" do
    expect(fonts("install", "comic_sans", "--into", dir)).to eq(1)
    expect(err.string).to include("unknown font pack \"comic_sans\"")
  end

  it "shows usage for a missing or unknown subcommand" do
    expect(fonts).to eq(2)
    expect(fonts("install")).to eq(2)
    expect(fonts("frobnicate")).to eq(2)
    expect(err.string).to include("Usage: stationery fonts list", "stationery fonts install PACK")
  end

  it "prints help" do
    expect(fonts("--help")).to eq(0)
    expect(out.string).to include("Usage: stationery fonts", "--into DIR", "--force", "--from PATH")
  end

  it "rejects unknown options" do
    expect(fonts("list", "--nope")).to eq(2)
    expect(err.string).to include("invalid option: --nope")
  end
end
