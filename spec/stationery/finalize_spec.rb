# frozen_string_literal: true

RSpec.describe Stationery, ".finalize!" do
  around { |example| BootState.around(&example) }

  it_behaves_like "a boot-finalized configuration",
                  readers: [described_class.method(:font_paths), described_class.method(:instrumenter)],
                  finalize: -> { described_class.finalize! }

  it "keeps the instrumenter in use, so one loaded after boot is not picked up" do
    described_class.finalize!
    stub_const("ActiveSupport::Notifications", Module.new)

    expect(described_class.instrumenter).to be(Stationery::Instrumentation::NULL)
  end

  it "keeps an instrumenter set at boot" do
    instrumenter = Stationery::Instrumentation::Null.new.freeze
    described_class.instrumenter = instrumenter
    described_class.finalize!

    expect(described_class.instrumenter).to be(instrumenter)
  end

  it "answers Stationery and may run again" do
    expect(described_class.finalize!).to be(described_class)
    expect(described_class.finalize!).to be(described_class)
  end
end
