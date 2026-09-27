# frozen_string_literal: true

require "fileutils"
require "tmpdir"

RSpec.describe Stationery::Fonts::Packs do
  let(:dir) { Dir.mktmpdir }
  let(:pack) { Stationery::Fonts::Catalog.fetch(:noto_sans) }

  def install_fixture(style, fixture)
    FileUtils.mkdir_p(File.join(dir, "noto_sans"))
    FileUtils.cp(font_path(fixture), File.join(dir, "noto_sans", pack.files.fetch(style).last))
  end

  before { Stationery.font_paths << dir }

  after do
    Stationery.font_paths.delete(dir)
    FileUtils.rm_rf(dir)
  end

  it "finds an installed pack by family name, case-insensitively" do
    install_fixture(:regular, "OpenSans-Regular.ttf")
    install_fixture(:bold, "OpenSans-Bold.ttf")
    family = described_class.family("noto sans")

    expect(family.name).to eq("Noto Sans")
    expect(family.paths).to eq(regular: File.join(dir, "noto_sans/NotoSans-Regular.ttf"),
                               bold: File.join(dir, "noto_sans/NotoSans-Bold.ttf"))
  end

  it "returns nil when the pack is not installed or the name is unknown" do
    expect(described_class.family("Noto Sans")).to be_nil
    expect(described_class.family("Comic Sans")).to be_nil
  end

  it "ignores a pack directory without its regular face" do
    install_fixture(:bold, "OpenSans-Bold.ttf")

    expect(described_class.family("Noto Sans")).to be_nil
  end

  it "lets font_family name an installed pack without paths" do
    install_fixture(:regular, "OpenSans-Regular.ttf")
    klass = Class.new(Stationery::Document) do
      font_family "Noto Sans"
      default_text font: "Noto Sans"
      define_method(:view_template) { text "Hello" }
    end

    expect(klass.new.to_pdf).to include("OpenSans")
  end
end
