# frozen_string_literal: true

require "open3"
require "stationery/cli"

RSpec.describe Stationery::CLI do
  let(:out) { StringIO.new }
  let(:err) { StringIO.new }

  def start(*argv) = described_class.start(argv, out:, err:)

  it "registers the render command" do
    expect(described_class.commands).to include("render" => Stationery::CLI::Render)
  end

  %w[help --help -h].each do |flag|
    it "prints usage listing every command for #{flag}" do
      expect(start(flag)).to eq(0)
      expect(out.string).to include("Usage: stationery COMMAND", "render", Stationery::CLI::Render::SUMMARY)
    end
  end

  it "prints usage to err and exits 2 without a command" do
    expect(start).to eq(2)
    expect(err.string).to include("Usage: stationery COMMAND", "render")
    expect(out.string).to be_empty
  end

  it "rejects an unknown command with exit 2" do
    expect(start("frobnicate")).to eq(2)
    expect(err.string).to include("unknown command \"frobnicate\"", "render")
  end

  %w[--version -v].each do |flag|
    it "prints the version for #{flag}" do
      expect(start(flag)).to eq(0)
      expect(out.string).to eq("#{Stationery::VERSION}\n")
    end
  end

  it "reports command errors on err with exit 1" do
    expect(start("render", "missing.rb")).to eq(1)
    expect(err.string).to include("stationery: no such file: missing.rb")
  end

  it "runs as an executable" do
    root = File.expand_path("../..", __dir__)
    lib = File.join(root, "lib")
    stdout, status = Open3.capture2(RbConfig.ruby, "-I#{lib}", File.join(root, "exe/stationery"), "--version")

    expect(status).to be_success
    expect(stdout).to eq("#{Stationery::VERSION}\n")
  end
end
