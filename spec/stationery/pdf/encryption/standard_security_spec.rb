# frozen_string_literal: true

RSpec.describe Stationery::PDF::Encryption::StandardSecurity do
  def build(**) = described_class.new(owner_password: "owner", **)
  def sizes(dictionary, *keys) = dictionary.values_at(*keys).map { |string| string.bytes.bytesize }

  describe "permission bits" do
    {
      [] => -3904,
      [:print] => -3900,
      %i[print copy] => -3884,
      [:modify] => -3896,
      [:annotate] => -3872,
      [:fill_forms] => -3648,
      [:extract_accessible] => -3392,
      [:assemble] => -2880,
      [:print_high] => -1856,
      described_class::PERMISSIONS.keys => -4
    }.each do |permissions, value|
      it "writes P #{value} for #{permissions.inspect}" do
        expect(build(permissions:).dictionary[:P]).to eq(value)
      end
    end

    it "grants everything by default" do
      expect(build.dictionary[:P]).to eq(-4)
    end
  end

  it "describes AES-256 as V5 R6 with AESV3 crypt filters" do
    dictionary = build.dictionary

    expect(dictionary).to include(Filter: :Standard, V: 5, R: 6, Length: 256, StmF: :StdCF, StrF: :StdCF)
    expect(dictionary[:CF]).to eq(StdCF: { CFM: :AESV3, AuthEvent: :DocOpen, Length: 32 })
    expect(sizes(dictionary, :O, :U, :OE, :UE, :Perms)).to eq([48, 48, 32, 32, 16])
  end

  it "describes AES-128 as V4 R4 with AESV2 crypt filters" do
    dictionary = build(algorithm: :aes_128).dictionary

    expect(dictionary).to include(V: 4, R: 4, Length: 128, StmF: :StdCF, StrF: :StdCF)
    expect(dictionary[:CF]).to eq(StdCF: { CFM: :AESV2, AuthEvent: :DocOpen, Length: 16 })
    expect(sizes(dictionary, :O, :U)).to eq([32, 32])
  end

  it "describes RC4 as V2 R3 without crypt filters" do
    dictionary = build(algorithm: :rc4_128).dictionary

    expect(dictionary).to include(V: 2, R: 3, Length: 128)
    expect(dictionary).not_to include(:CF)
    expect(sizes(dictionary, :O, :U)).to eq([32, 32])
  end

  it "uses a fresh 16-byte file ID and fresh keys per instance" do
    expect(build.file_id.bytesize).to eq(16)
    expect(build.file_id).not_to eq(build.file_id)
    expect(build.encrypt("x", 1)).not_to eq(build.encrypt("x", 1))
  end

  it "encrypts per object for RC4 and AES-128 and with the file key for AES-256" do
    rc4 = build(algorithm: :rc4_128)

    expect(rc4.encrypt("hello", 1)).not_to eq(rc4.encrypt("hello", 2))
    expect(rc4.encrypt("hello", 1).bytesize).to eq(5)
    expect(build(algorithm: :aes_128).encrypt("hello", 1).bytesize).to eq(32)
    expect(build.encrypt("", 1).bytesize).to eq(32)
  end

  it "rejects a missing owner password, unknown permissions and unknown algorithms" do
    expect { described_class.new(owner_password: nil) }.to raise_error(ArgumentError, /owner_password/)
    expect { build(permissions: [:fly]) }.to raise_error(ArgumentError, /unknown permission :fly/)
    expect { build(algorithm: :des) }.to raise_error(ArgumentError, /unknown algorithm :des/)
  end
end
