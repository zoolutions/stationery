# frozen_string_literal: true

require "fileutils"
require "tmpdir"

RSpec.describe Stationery::Fonts do
  it "maps each style of a pack to its file under dir" do
    expect(described_class.paths(:noto_sans_mono, dir: "vendor/fonts"))
      .to eq(regular: "vendor/fonts/noto_sans_mono/NotoSansMono-Regular.ttf",
             bold: "vendor/fonts/noto_sans_mono/NotoSansMono-Bold.ttf")
    expect(described_class.paths("inter")[:italic]).to eq("vendor/fonts/inter/Inter-Italic.ttf")
  end

  it "lists the catalog" do
    expect(described_class.catalog).to eq(Stationery::Fonts::Catalog::PACKS)
  end

  it "installs a pack" do
    Dir.mktmpdir do |dir|
      paths = described_class.install(:inter, into: dir)

      expect(paths[:bold]).to eq(File.join(dir, "inter/Inter-Bold.ttf"))
      expect(File).to exist(paths[:bold])
    end
  end

  describe ".usage" do
    it "shows the name alone when the directory is in Stationery.font_paths" do
      Dir.mktmpdir do |dir|
        Stationery.font_paths << dir
        expect(described_class.usage(:noto_sans, dir)).to eq(['font_family "Noto Sans"'])
      ensure
        Stationery.font_paths.delete(dir)
      end
    end

    it "shows explicit paths otherwise" do
      expect(described_class.usage(:noto_sans, "fonts").last)
        .to eq('font_family "Noto Sans", **Stationery::Fonts.paths(:noto_sans, dir: "fonts")')
    end
  end
end
