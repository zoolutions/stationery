# frozen_string_literal: true

require "open3"

RSpec.describe Stationery::Fonts::Bundled do
  it "lists the families shipped in the gem" do
    expect(described_class.names).to eq(["Inter"])
    expect(Stationery.bundled_fonts).to eq(["Inter"])
  end

  it "builds a family whose four faces all parse" do
    family = described_class.family("Inter")

    expect(family.paths.keys).to contain_exactly(:regular, :bold, :italic, :bold_italic)
    family.paths.each_value do |path|
      expect(Stationery::Fonts::TrueType.new(File.binread(path)).postscript_name).to start_with("Inter")
    end
  end

  it "returns nil for a family it does not ship" do
    expect(described_class.family("Nope")).to be_nil
  end

  it "ships the license next to the files" do
    expect(File.read(File.join(described_class::DIR, "OFL.txt"))).to include("SIL Open Font License")
  end

  it "reads no font file when the gem is required" do
    script = <<~RUBY
      reads = []
      File.singleton_class.prepend(Module.new { define_method(:binread) { |path, *rest| reads << path; super(path, *rest) } })
      require "stationery"
      print reads.grep(/fonts\\/data/).size
    RUBY
    out, status = Open3.capture2("ruby", "-I", File.expand_path("../../../lib", __dir__), "-e", script)

    expect(status).to be_success
    expect(out).to eq("0")
  end
end
