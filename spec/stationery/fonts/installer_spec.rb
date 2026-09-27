# frozen_string_literal: true

require "digest"
require "fileutils"
require "net/http"
require "rubygems/package"
require "tmpdir"
require "zlib"

RSpec.describe Stationery::Fonts::Installer do
  let(:dir) { Dir.mktmpdir }
  let(:out) { StringIO.new }
  let(:responses) do
    { "https://fonts.test/Fake-Regular.ttf" => regular,
      "https://fonts.test/fake-1.0.tar.gz" => tar_gz("fake-1.0/Fake-Bold.ttf" => bold, "fake-1.0/LICENSE" => license) }
  end
  let(:requests) { [] }
  let(:fetcher) do
    lambda do |url|
      requests << url
      responses.fetch(url)
    end
  end

  def regular = File.binread(font_path("OpenSans-Regular.ttf"))
  def bold = File.binread(font_path("OpenSans-Bold.ttf"))
  def license = "SIL Open Font License 1.1\n"

  def pack
    Stationery::Fonts::Catalog::Pack.new(
      key: :fake, family: "Fake Sans", license: "OFL-1.1",
      files: { regular: ["https://fonts.test/Fake-Regular.ttf", sha(regular), "Fake-Regular.ttf"],
               bold: ["https://fonts.test/fake-1.0.tar.gz#fake-1.0/Fake-Bold.ttf", sha(bold), "Fake-Bold.ttf"] },
      license_file: ["https://fonts.test/fake-1.0.tar.gz#fake-1.0/LICENSE", sha(license), "OFL.txt"]
    )
  end

  def sha(bytes) = Digest::SHA256.hexdigest(bytes)
  def installer(**) = described_class.new(into: dir, out:, fetcher:, **)
  def installed = Dir.children(File.join(dir, "fake")).sort

  def tar_gz(entries)
    tar = StringIO.new
    Gem::Package::TarWriter.new(tar) do |writer|
      entries.each { |name, bytes| writer.add_file_simple(name, 0o644, bytes.bytesize) { it.write(bytes) } }
    end
    gz = StringIO.new
    Zlib::GzipWriter.wrap(gz) { it.write(tar.string) }
    gz.string
  end

  before { stub_const("Stationery::Fonts::Catalog::PACKS", [pack, *Stationery::Fonts::Catalog::PACKS]) }
  after { FileUtils.rm_rf(dir) }

  it "downloads, verifies and writes each face and the license into DIR/<pack>" do
    paths = installer.install(:fake)

    expect(paths).to eq(regular: File.join(dir, "fake/Fake-Regular.ttf"), bold: File.join(dir, "fake/Fake-Bold.ttf"))
    expect(File.binread(paths[:bold])).to eq(bold)
    expect(File.read(File.join(dir, "fake/OFL.txt"))).to eq(license)
    expect(installed).to eq(%w[Fake-Bold.ttf Fake-Regular.ttf OFL.txt])
    expect(requests).to eq(["https://fonts.test/Fake-Regular.ttf", "https://fonts.test/fake-1.0.tar.gz"])
    expect(out.string).to include("fetch https://fonts.test/Fake-Regular.ttf", "wrote #{paths[:regular]}")
  end

  it "writes nothing when any SHA-256 does not match" do
    responses["https://fonts.test/fake-1.0.tar.gz"] = tar_gz("fake-1.0/Fake-Bold.ttf" => regular,
                                                             "fake-1.0/LICENSE" => license)

    expect { installer.install(:fake) }
      .to raise_error(Stationery::Error,
                      /SHA-256 mismatch for Fake-Bold\.ttf: expected #{sha(bold)}, got #{sha(regular)}/)
    expect(Dir.glob("**/*", File::FNM_DOTMATCH, base: dir) - ["."]).to be_empty
  end

  it "fails when an archive lacks a member" do
    responses["https://fonts.test/fake-1.0.tar.gz"] = tar_gz("fake-1.0/Fake-Bold.ttf" => bold)

    expect { installer.install(:fake) }.to raise_error(Stationery::Error, %r{fake-1\.0/LICENSE not found})
  end

  it "skips files that exist unless force: is given" do
    installer.install(:fake)
    File.binwrite(File.join(dir, "fake/Fake-Regular.ttf"), "old")
    requests.clear

    installer.install(:fake)
    expect(File.binread(File.join(dir, "fake/Fake-Regular.ttf"))).to eq("old")
    expect(requests).to be_empty
    expect(out.string).to include("exists #{File.join(dir, "fake/Fake-Regular.ttf")}")

    installer(force: true).install(:fake)
    expect(File.binread(File.join(dir, "fake/Fake-Regular.ttf"))).to eq(regular)
  end

  it "installs offline from a directory, matching files by name anywhere below it" do
    from = File.join(dir, "download")
    FileUtils.mkdir_p(File.join(from, "nested"))
    File.binwrite(File.join(from, "Fake-Regular.ttf"), regular)
    File.binwrite(File.join(from, "nested/Fake-Bold.ttf"), bold)
    File.binwrite(File.join(from, "LICENSE"), license)

    expect(installer(from:).install(:fake).keys).to eq(%i[regular bold])
    expect(requests).to be_empty
    expect(installed).to eq(%w[Fake-Bold.ttf Fake-Regular.ttf OFL.txt])
  end

  it "installs offline from a .tar.gz, still checking SHAs" do
    from = File.join(dir, "fonts.tar.gz")
    File.binwrite(from, tar_gz("x/Fake-Regular.ttf" => regular, "x/Fake-Bold.ttf" => bold, "x/LICENSE" => license))

    installer(from:).install(:fake)
    expect(installed).to eq(%w[Fake-Bold.ttf Fake-Regular.ttf OFL.txt])

    File.binwrite(from, tar_gz("x/Fake-Regular.ttf" => bold))
    expect { installer(from:, force: true).install(:fake) }.to raise_error(Stationery::Error, /SHA-256 mismatch/)
  end

  it "reports a file missing from the offline source" do
    expect { installer(from: dir).install(:fake) }.to raise_error(Stationery::Error, /Fake-Regular\.ttf not found in/)
  end

  it "copies inter from the bundled files without fetching" do
    paths = installer.install(:inter)

    expect(paths.keys).to eq(%i[regular bold italic bold_italic])
    expect(File.binread(paths[:regular])).to eq(File.binread(File.join(Stationery::Fonts::Bundled::DIR,
                                                                       "Inter-Regular.ttf")))
    expect(File).to exist(File.join(dir, "inter/OFL.txt"))
    expect(requests).to be_empty
  end

  it "defaults to vendor/fonts" do
    expect(described_class.new.into).to eq("vendor/fonts")
  end

  describe "the HTTPS fetcher" do
    def response(klass, code, body: nil, location: nil)
      klass.new("1.1", code, "").tap do |res|
        res["location"] = location if location
        allow(res).to receive(:body).and_return(body)
      end
    end

    it "follows redirects and returns the body as binary" do
      allow(Net::HTTP).to receive(:get_response) do |uri|
        if uri.path == "/a" then response(Net::HTTPFound, "302", location: "/b")
        else response(Net::HTTPOK, "200", body: +"bytes")
        end
      end

      expect(described_class::HTTP.call("https://fonts.test/a")).to eq("bytes").and have_attributes(encoding: Encoding::BINARY)
      expect(Net::HTTP).to have_received(:get_response).with(URI("https://fonts.test/b"))
    end

    it "gives up after five redirects and on errors" do
      allow(Net::HTTP).to receive(:get_response).and_return(response(Net::HTTPFound, "302", location: "/again"))
      expect do
        described_class::HTTP.call("https://fonts.test/a")
      end.to raise_error(Stationery::Error, /too many redirects/)

      allow(Net::HTTP).to receive(:get_response).and_return(response(Net::HTTPNotFound, "404"))
      expect do
        described_class::HTTP.call("https://fonts.test/a")
      end.to raise_error(Stationery::Error, /404.*fonts\.test/)
    end

    it "refuses plain http" do
      expect { described_class::HTTP.call("http://fonts.test/a") }.to raise_error(Stationery::Error, /https/)
    end
  end
end
