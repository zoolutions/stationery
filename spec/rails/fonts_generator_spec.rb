# frozen_string_literal: true

require_relative "spec_helper"
require "tmpdir"
require "generators/stationery/fonts_generator"

RSpec.describe Stationery::Generators::FontsGenerator do
  let(:root) { Dir.mktmpdir }

  after { FileUtils.remove_entry(root) }

  it "is found by Rails as stationery:fonts" do
    expect(Rails::Generators.find_by_namespace("stationery:fonts")).to eq(described_class)
  end

  it "installs packs under the app's vendor/fonts" do
    expect { described_class.start(%w[inter], destination_root: root) }
      .to output(%r{wrote .*vendor/fonts/inter/Inter-Regular\.ttf.*Use it with: font_family "Inter"}m).to_stdout
    expect(File).to exist(File.join(root, "vendor/fonts/inter/Inter-Bold.ttf"))
  end

  it "honours --into and --force" do
    allow(Stationery::Fonts).to receive(:install)
    expect { described_class.start(%w[noto_sans --into app/fonts --force], destination_root: root) }
      .to output(%r{Stationery::Fonts\.paths\(:noto_sans, dir: "app/fonts"\)}).to_stdout

    expect(Stationery::Fonts).to have_received(:install)
      .with("noto_sans", into: File.join(root, "app/fonts"), force: true, out: anything)
  end
end
