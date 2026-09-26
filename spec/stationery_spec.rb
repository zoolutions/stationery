# frozen_string_literal: true

RSpec.describe Stationery do
  it "has a version number" do
    expect(Stationery::VERSION).to match(/\A\d+\.\d+\.\d+/)
  end
end
