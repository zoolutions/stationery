# frozen_string_literal: true

RSpec.describe Stationery, ".font_paths" do
  around { |example| BootState.around(&example) }

  it "takes directories until finalize!" do
    described_class.font_paths << "/fonts/early"

    expect(described_class.font_paths).to eq(["/fonts/early"])
  end

  it "is frozen by finalize!, with every directory added before it" do
    dir = +"/fonts/app"
    described_class.font_paths << dir
    described_class.finalize!

    expect(described_class.font_paths).to eq(["/fonts/app"])
    expect(described_class.font_paths).to be_frozen
    expect(described_class.font_paths).to all(be_frozen)
    expect { described_class.font_paths << "/fonts/late" }.to raise_error(FrozenError)
  end

  it "leaves the Strings it was given alone" do
    dir = +"/fonts/app"
    described_class.font_paths << dir
    described_class.finalize!

    expect(dir).not_to be_frozen
  end

  it "is Ractor-shareable once finalized", if: defined?(Ractor) do
    described_class.font_paths << +"/fonts/app"
    described_class.finalize!

    expect(Ractor.shareable?(described_class.font_paths)).to be(true)
  end
end
