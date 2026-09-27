# frozen_string_literal: true

RSpec.describe Stationery::PDF::Encryption::RC4 do
  it "matches the published test vectors" do
    expect(described_class.crypt("Key", "Plaintext").unpack1("H*")).to eq("bbf316e8d940af0ad3")
    expect(described_class.crypt("Wiki", "pedia").unpack1("H*")).to eq("1021bf0420")
    expect(described_class.crypt("Secret", "Attack at dawn").unpack1("H*")).to eq("45a01f645fc35b383552544b9bf5")
  end

  it "is its own inverse and returns binary" do
    key = "\x01\x02\x03\x04\x05".b
    result = described_class.crypt(key, described_class.crypt(key, "hello"))

    expect(result).to eq("hello")
    expect(result.encoding).to eq(Encoding::BINARY)
  end
end
