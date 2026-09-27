# frozen_string_literal: true

RSpec.describe Stationery::Rich::Inline do
  it "freezes a copy of its marks" do
    marks = { bold: true }
    inline = described_class.new(text: "a", marks:)

    expect(inline.marks).to be_frozen
    expect(marks).not_to be_frozen
    expect(described_class.new(text: "a").marks).to eq({})
  end

  it "knows hard breaks" do
    expect(described_class.new(text: "a")).not_to be_break
    expect(described_class.break).to be_break
    expect(described_class.break.text).to eq("")
  end
end
