# frozen_string_literal: true

require "stationery/verify"

RSpec.describe Stationery::Verify::Expectation do
  def read(subject, password: nil) = described_class.read(Stationery::Testing::Inspector.new(subject, password:))

  it "holds each page's text lines, links and whether it has content" do
    expectation = read(RenderDigests.example("invoice"))

    expect(expectation.pages.size).to eq(1)
    expect(expectation.pages[0].lines).to include("Invoice INV-2026-042", "Rush delivery")
    expect(expectation.pages[0].links).to eq([{ uri: "mailto:hello@acme.test" }])
    expect(expectation.pages[0].content).to be(true)
    expect(expectation).to have_attributes(outline: [], attachments: [], signatures: 0, tagged: false)
  end

  it "holds the fields once by name, with a text field's value" do
    fields = read(RenderDigests.example("form")).fields

    expect(fields.map { it[:name] }).to eq(fields.map { it[:name] }.uniq)
    expect(fields).to include({ name: "applicant.name", type: :text, value: "Astrid Lindqvist", visible: true },
                              { name: "plan", type: :radio, value: "pro", visible: true })
  end

  it "says a field whose widgets have no area is not visible" do
    signed = RenderDigests.example("invoice").to_pdf(sign: SignatureHelpers.identity(:rsa).to_h)

    expect(read(signed).fields).to eq([{ name: "Signature1", type: :signature, value: "signed", visible: false }])
  end

  it "holds the outline's titles in order, the attachments and whether the file is tagged" do
    report = read(RenderDigests.example("report"))
    invoice = read(RenderDigests.example("e_invoice"))

    expect(report.outline.first(3)).to eq(["Contents", "Introduction", "About this report"])
    expect(report.tagged).to be(true)
    expect(report.pages[1].links).to include({ page: 3 })
    expect(invoice.attachments).to eq(["factur-x.xml"])
  end

  it "reads an encrypted file with its password" do
    pdf = RenderDigests.example("invoice").to_pdf(encrypt: { user_password: "secret", owner_password: "owner" })

    expect(read(pdf, password: "secret").pages[0].lines).to include("Rush delivery")
  end

  it "says a blank page has no content" do
    blank = Class.new(Stationery::Document) { def view_template = page_break }.new

    expect(read(blank).pages.map(&:content)).to eq([false])
  end
end
