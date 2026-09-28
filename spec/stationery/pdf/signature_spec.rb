# frozen_string_literal: true

RSpec.describe Stationery::PDF::Signature do
  let(:certificate) { signer.certificate }
  let(:key) { signer.key }
  let(:document) do
    Class.new(SpecDocument) do
      metadata title: "Contract", lang: "en"

      def view_template
        text "Contract"
        signature_field "approval", width: 160, label: "Approved by"
      end

      def signing_key = SignatureHelpers.identity(:rsa).key
    end
  end
  let(:plain) { Class.new(SpecDocument) { define_method(:view_template) { text "Contract" } } }

  describe ".for" do
    it "is nil without a spec and takes certificates and keys as objects or PEM" do
      expect(described_class.for(nil, document.new)).to be_nil

      signature = described_class.for({ certificate: certificate.to_pem, "key" => key.to_pem }, document.new)
      expect(signature.certificate.to_der).to eq(certificate.to_der)
      expect(signature.key.to_der).to eq(key.to_der)
      expect(signature).to have_attributes(chain: [], field: nil, contents_size: 8192, name: "Test Signer rsa")
      expect(signature).to be_invisible
    end

    it "reads an encrypted key with its passphrase" do
      pem = key.to_pem(OpenSSL::Cipher.new("aes-256-cbc"), "secret")

      expect(described_class.for({ certificate:, key: pem, passphrase: "secret" }, document.new).key.to_der)
        .to eq(key.to_der)
      expect { described_class.for({ certificate:, key: pem, passphrase: "wrong" }, document.new) }
        .to raise_error(ArgumentError, /sign key: needs an OpenSSL::PKey or its PEM \(with passphrase:/)
    end

    it "evaluates blocks in the document, calls callables with it and sends method names for secrets" do
      instance = document.new
      cert = certificate
      signature = described_class.for(
        { certificate: ->(_doc) { cert }, key: :signing_key, reason: -> { metadata[:title] }, field: :approval },
        instance
      )

      expect(signature.key.to_der).to eq(key.to_der)
      expect(signature.field).to eq("approval")
      expect(signature.dictionary[:Reason].value).to eq("Contract")
      expect(described_class.for(-> { { certificate: cert, key: signing_key } }, instance).certificate).to eq(cert)
    end

    it "refuses unknown options, anything that is not a certificate or key, and a key of another certificate" do
      other = SignatureHelpers.identity(:ec)

      expect { described_class.for({ certificate:, key:, signer: "x" }, document.new) }
        .to raise_error(ArgumentError, /\Aunknown sign option: signer \(use certificate, key, chain/)
      expect { described_class.for({ certificate: "nope", key: }, document.new) }
        .to raise_error(ArgumentError, "sign certificate: needs an OpenSSL::X509::Certificate or its PEM, got a String")
      expect { described_class.for({ certificate:, key: nil }, document.new) }
        .to raise_error(ArgumentError, /sign key: needs an OpenSSL::PKey or its PEM .*got nil/)
      expect { described_class.for({ certificate:, key:, chain: ["nope"] }, document.new) }
        .to raise_error(ArgumentError, /sign chain: needs an OpenSSL::X509::Certificate/)
      expect { described_class.for({ certificate:, key: other.key }, document.new) }
        .to raise_error(ArgumentError, /sign key: is not the private key of certificate: \(CN=Test Signer rsa/)
      expect { described_class.for({ certificate:, key: OpenSSL::PKey.generate_key("ED25519") }, document.new) }
        .to raise_error(ArgumentError, /sign key: needs an RSA or EC key/)
    end
  end

  describe ".der" do
    it "cuts the zero padding off a DER object with a short or a long length" do
      short = OpenSSL::ASN1::OctetString.new("a" * 10).to_der
      long = OpenSSL::ASN1::OctetString.new("a" * 300).to_der

      expect(described_class.der("#{short}#{"\0" * 20}")).to eq(short)
      expect(described_class.der("#{long}#{"\0" * 20}")).to eq(long)
    end
  end

  describe "#dictionary" do
    it "names the filter, the signer and what was said about the signature" do
      signature = described_class.new(certificate:, key:, reason: "Approved", location: "Malmö",
                                      contact: "legal@example.test", at: Time.utc(2026, 9, 28, 12, 30))

      expect(signature.dictionary).to include(
        Type: :Sig, Filter: :"Adobe.PPKLite", SubFilter: :"ETSI.CAdES.detached",
        M: Stationery::PDF::TextString.new("D:20260928123000Z"),
        Name: Stationery::PDF::TextString.new("Test Signer rsa"),
        Reason: Stationery::PDF::TextString.new("Approved"), Location: Stationery::PDF::TextString.new("Malmö"),
        ContactInfo: Stationery::PDF::TextString.new("legal@example.test")
      )
      expect(signature.dictionary[:ByteRange].source).to eq("[0 0000000000 0000000000 0000000000]")
      expect(signature.dictionary[:Contents].source).to eq("<#{"0" * 16_384}>")
    end

    it "takes another name and leaves out what was not said" do
      dictionary = described_class.new(certificate:, key:, name: "Legal department").dictionary

      expect(dictionary[:Name].value).to eq("Legal department")
      expect(dictionary.keys).to eq(%i[Type Filter SubFilter ByteRange Contents M Name])
    end
  end

  describe "an invisible signature" do
    let(:pdf) { plain.new.to_pdf(sign: { certificate:, key:, reason: "Approved", location: "Malmö" }) }

    it "adds a field of its own whose widget has no size, on the first page" do
      form = acro_form(pdf)
      field = form_fields(pdf).fetch("Signature1")
      page = reader_for(pdf).pages.first

      expect(form).to include(SigFlags: 3)
      expect(form).not_to have_key(:NeedAppearances)
      expect(field).to include(FT: :Sig, Subtype: :Widget, F: 132, Rect: [0, 0, 0, 0])
      expect(field).not_to have_key(:AP)
      expect(decode_text(field[:TU])).to eq("Signature1")
      expect(page.attributes[:Annots].size).to eq(1)
      expect(form_objects(pdf).deref(field[:V])).to include(Type: :Sig, SubFilter: :"ETSI.CAdES.detached")
    end

    it "signs every byte of the file but the signature itself" do
      cms, _signed, range = signed_parts(pdf)

      expect(range[0]).to eq(0)
      expect(range[2] - range[1]).to eq(16_386)
      expect(range[2] + range[3]).to eq(pdf.bytesize)
      expect(pdf.byteslice(range[1], 1)).to eq("<")
      expect(pdf.byteslice(range[2] - 1, 1)).to eq(">")
      expect(cms.bytesize).to be < 2000
    end

    it "is read back, and verified, by the inspector" do
      expect(inspect_pdf(pdf).signatures).to match([{
                                                     field: "Signature1", name: "Test Signer rsa", reason: "Approved",
                                                     location: "Malmö", signed_at: be_within(60).of(Time.now),
                                                     subfilter: :"ETSI.CAdES.detached",
                                                     byte_range: signed_parts(pdf).last,
                                                     signer: "CN=Test Signer rsa,O=Stationery,C=SE", valid: true
                                                   }])
    end

    it "takes a free name when the document has a field called Signature1" do
      taken = Class.new(SpecDocument) do
        define_method(:view_template) do
          text_field "Signature1.note"
          signature_field "Signature2"
        end
      end

      expect(inspect_pdf(taken.new.to_pdf(sign: { certificate:, key: })).signatures.map { it[:field] })
        .to eq(["Signature3"])
    end

    it "is verified by openssl" do
      verdict = openssl_verdict(pdf)
      skip "openssl is not installed" unless verdict

      expect(verdict).to include("Verification successful")
    end
  end

  describe "the signed attributes" do
    it "bind the content type, the digest and the signing certificate, and no signing time" do
      cms, signed, = signed_parts(plain.new.to_pdf(sign: { certificate:, key: }))
      signer_info = OpenSSL::ASN1.decode(cms).value[1].value[0].value[4].value[0]
      attributes = signer_info.value[3].value.to_h { |attribute| [attribute.value[0].oid, attribute.value[1].value[0]] }

      expect(attributes.keys).to contain_exactly("1.2.840.113549.1.9.3", "1.2.840.113549.1.9.4",
                                                 "1.2.840.113549.1.9.16.2.47")
      expect(attributes["1.2.840.113549.1.9.4"].value).to eq(OpenSSL::Digest::SHA256.digest(signed))
      expect(attributes["1.2.840.113549.1.9.16.2.47"].value[0].value[0].value[0].value)
        .to eq(OpenSSL::Digest::SHA256.digest(certificate.to_der))
    end
  end

  describe "filling a signature field" do
    it "gives the named field its value and keeps the widget's appearance" do
      pdf = document.new.to_pdf(sign: { certificate:, key:, field: "approval" })
      field = form_fields(pdf).fetch("approval")

      expect(form_fields(pdf).keys).to eq(["approval"])
      expect(field).to include(FT: :Sig, F: 4)
      expect(field[:Rect][2] - field[:Rect][0]).to eq(160)
      expect(appearance_text(pdf, field)).to eq(["Approved by"])
      expect(inspect_pdf(pdf).signatures).to match([include(field: "approval", valid: true)])
    end

    it "leaves other signature fields empty" do
      pdf = document.new.to_pdf(sign: { certificate:, key: })

      expect(form_fields(pdf).fetch("approval")).not_to have_key(:V)
      expect(inspect_pdf(pdf).signatures.map { it[:field] }).to eq(["Signature1"])
    end

    it "refuses a field the document does not have" do
      expect { document.new.to_pdf(sign: { certificate:, key:, field: "missing" }) }
        .to raise_error(ArgumentError, 'sign field: names "missing", but the document has no such signature_field')
      expect { plain.new.to_pdf(sign: { certificate:, key:, field: "approval" }) }
        .to raise_error(ArgumentError, /no such signature_field/)
    end
  end

  it "signs with an EC key and carries the certificate chain" do
    root = SignatureHelpers.identity(:rsa)
    leaf_key = SignatureHelpers.identity(:ec).key
    leaf = SignatureHelpers.certificate(leaf_key, "Leaf", issuer: root)
    pdf = plain.new.to_pdf(sign: { certificate: leaf, key: leaf_key, chain: [root.certificate.to_pem] })
    cms, = signed_parts(pdf)

    expect(inspect_pdf(pdf).signatures).to match([include(signer: "CN=Leaf,O=Stationery,C=SE", valid: true)])
    expect(OpenSSL::PKCS7.new(cms).certificates.map { it.subject.to_utf8 })
      .to eq(["CN=Leaf,O=Stationery,C=SE", "CN=Test Signer rsa,O=Stationery,C=SE"])
    expect(openssl_verdict(pdf)).to include("Verification successful") if openssl_verdict(pdf)
  end

  it "is invalid once a signed byte changes" do
    pdf = plain.new.to_pdf(sign: { certificate:, key: })
    tampered = pdf.dup
    tampered.setbyte(12, tampered.getbyte(12) ^ 1)
    truncated = pdf.byteslice(0, pdf.bytesize - 1)

    expect(inspect_pdf(pdf).signatures.first).to include(valid: true)
    expect(inspect_pdf(tampered).signatures.first).to include(valid: false, signer: /Test Signer/)
    expect(inspect_pdf(truncated).signatures.first).to include(valid: false)
  end

  it "refuses a signature that does not fit and says how to make room" do
    expect { plain.new.to_pdf(sign: { certificate:, key:, contents_size: 512 }) }
      .to raise_error(ArgumentError, /\Athe signature takes \d+ bytes, more than contents_size: 512 leaves for it/)
    expect(inspect_pdf(plain.new.to_pdf(sign: { certificate:, key:, contents_size: 4096 })).signatures.first)
      .to include(valid: true)
  end

  it "signs an encrypted file, leaving the signature itself in the clear" do
    pdf = plain.new.to_pdf(sign: { certificate:, key:, reason: "Approved" }, encrypt: { owner_password: "owner" })
    cms, = signed_parts(pdf)

    expect(pdf).to include("/Encrypt")
    expect(OpenSSL::PKCS7.new(cms).certificates.first.to_der).to eq(certificate.to_der)
    expect(inspect_pdf(pdf).signatures).to match([include(reason: "Approved", name: "Test Signer rsa", valid: true)])
  end

  it "keeps a PDF/A and PDF/UA claim" do
    pdf = document.new.to_pdf(sign: { certificate:, key: }, conformance: %i[pdf_a3b pdf_ua1])
    page = form_objects(pdf).deref(form_objects(pdf).page_references.first)

    expect(inspect_pdf(pdf).conformance).to eq(%i[pdf_a3b pdf_ua1])
    expect(inspect_pdf(pdf).signatures.first).to include(valid: true)
    expect(page).to include(Tabs: :S)
  end

  it "gives a PDF/UA page its tab order when the signature is its only annotation" do
    titled = Class.new(plain) { metadata title: "Contract", lang: "en" }
    objects = form_objects(titled.new.to_pdf(sign: { certificate:, key: }, conformance: :pdf_ua1))

    expect(objects.deref(objects.page_references.first)).to include(Tabs: :S)
    expect(acro_form(titled.new.to_pdf(conformance: :pdf_ua1))).to be_nil
  end

  describe "declared on the class" do
    it "signs every render, with values read when the document renders" do
      cert = certificate
      declared = Class.new(document) { sign certificate: cert, key: :signing_key, reason: "Declared" }
      by_block = Class.new(document) { sign { { certificate: cert, key: signing_key, field: "approval" } } }

      expect(inspect_pdf(declared.new.to_pdf).signatures).to match([include(reason: "Declared", valid: true)])
      expect(inspect_pdf(by_block.new.to_pdf).signatures).to match([include(field: "approval", valid: true)])
      expect(inspect_pdf(declared.new.to_pdf(sign: nil)).signatures).to eq([])
    end

    it "validates what it can when declared" do
      cert = certificate
      pem = key.to_pem

      expect { Class.new(document) { sign } }
        .to raise_error(ArgumentError, "sign needs certificate: and key:, or a block answering them")
      expect { Class.new(document) { sign certificate: cert, key: pem, stamp: true } }
        .to raise_error(ArgumentError, /unknown sign option: stamp/)
      expect { Class.new(document) { sign certificate: "nope", key: pem } }
        .to raise_error(ArgumentError, /sign certificate: needs/)
      expect { Class.new(document) { sign certificate: :missing_method, key: pem } }.not_to raise_error
    end
  end

  it "changes nothing without a signature" do
    allow(Time).to receive(:now).and_return(Time.utc(2026, 9, 28, 12))
    cert = certificate
    pem = key.to_pem
    declared = Class.new(document) { sign certificate: cert, key: pem }

    expect(declared.new.to_pdf(sign: nil)).to eq(document.new.to_pdf)
  end
end
