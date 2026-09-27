# frozen_string_literal: true

RSpec.describe Stationery do
  it "has a version number" do
    expect(Stationery::VERSION).to match(/\A\d+\.\d+\.\d+/)
  end

  it "keeps a process-wide list of font directories" do
    expect(described_class.font_paths).to be_an(Array)
  end
end
