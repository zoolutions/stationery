# frozen_string_literal: true

require "digest"

RSpec.describe Stationery::Fonts::Catalog do
  let(:packs) { described_class::PACKS }

  it "has unique keys" do
    expect(packs.map(&:key)).to eq(packs.map(&:key).uniq)
    expect(packs.map(&:key)).to include(:inter, :noto_sans, :noto_serif, :noto_sans_mono,
                                        :liberation_sans, :liberation_serif, :liberation_mono)
  end

  it "gives every pack 1–4 files with a regular face, 64-hex SHAs and a license" do
    packs.each do |pack|
      expect(pack.files.size).to be_between(1, 4)
      expect(pack.files).to include(:regular)
      expect(pack.files.keys - Stationery::Fonts::Family::STYLES).to be_empty
      [*pack.files.values, pack.license_file].each do |_url, sha, filename|
        expect(sha).to match(/\A\h{64}\z/)
        expect(filename).to match(/\A[\w.-]+\z/)
      end
      expect(pack.license).to include("OFL")
    end
  end

  it "points every download at a pinned https URL" do
    urls = packs.flat_map { |pack| [*pack.files.values, pack.license_file].map(&:first) }.compact

    expect(urls).not_to be_empty
    expect(urls).to all(start_with("https://"))
    expect(urls.grep(/raw\.githubusercontent/)).to all(match(%r{/(\h{40}|NotoSans-v[\d.]+)/}))
  end

  it "copies inter from the bundled files, whose SHAs match" do
    inter = described_class.fetch(:inter)

    [*inter.files.values, inter.license_file].each do |url, sha, filename|
      expect(url).to be_nil
      expect(Digest::SHA256.file(File.join(Stationery::Fonts::Bundled::DIR, filename)).hexdigest).to eq(sha)
    end
    expect(inter.files.transform_values(&:last)).to eq(Stationery::Fonts::Bundled::FAMILIES.fetch("Inter"))
  end

  it "finds packs by symbol or string and rejects unknown keys" do
    expect(described_class.fetch("noto_sans").family).to eq("Noto Sans")
    expect { described_class.fetch(:comic) }.to raise_error(Stationery::Error, /unknown font pack "comic".*noto_sans/)
  end
end
