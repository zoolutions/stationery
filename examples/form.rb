# frozen_string_literal: true

# A one-page membership application with every kind of form field: text
# inputs, a multiline note, a comb field, a select box, a radio group, check
# boxes and a signature field. Run it to write examples/form.pdf:
#
#   ruby -Ilib examples/form.rb
#   ruby -Ilib exe/stationery render examples/form.rb
require "stationery"

class ExampleForm < Stationery::Document
  ACCENT = "#0F766E"
  INK = "#111827"
  MUTED = "#6B7280"
  HAIRLINE = "#E5E7EB"
  PLANS = { "basic" => "Basic · SEK 290 / year", "pro" => "Pro · SEK 590 / year",
            "team" => "Team · SEK 1,490 / year" }.freeze

  page size: :a4, margin: [48, 56, 40, 56]
  default_text size: 9.5, color: INK
  metadata title: "Membership application", author: "Nordic Makers Guild", creator: "stationery example"

  footer do
    rule height: 0.5, color: HAIRLINE
    spacer 6
    text "Nordic Makers Guild · Box 118, 221 00 Lund · members@makers.example", size: 7.5, color: MUTED,
                                                                                align: :center
  end

  def self.preview = new(name: "Astrid Lindqvist", email: "astrid@example.se", plan: "pro")

  def initialize(name: "", email: "", plan: nil)
    super()
    @name = name
    @email = email
    @plan = plan
  end

  def view_template
    text "Membership application", size: 20, weight: :bold, color: ACCENT
    text "Fill in the form on screen, sign it and send it back to us.", color: MUTED
    spacer 20
    applicant
    spacer 18
    membership
    spacer 18
    consent
  end

  private

  def heading(title)
    text title, size: 11, weight: :bold, keep_with_next: true
    rule height: 0.5, color: HAIRLINE
    spacer 8
  end

  def labelled(label)
    column do
      text label, size: 8, color: MUTED
      spacer 3
      yield
    end
  end

  def applicant
    heading "Applicant"
    row(gap: 12) do
      labelled("Full name") { text_field "applicant.name", value: @name, required: true }
      labelled("Email") { text_field "applicant.email", value: @email, required: true }
    end
    spacer 10
    row(gap: 12) do
      labelled("Street address") { text_field "applicant.address.street" }
      column(width: 90) { labelled("Postcode") { text_field "applicant.address.postcode", comb: 5 } }
      labelled("Country") do
        select "applicant.address.country", options: %w[Sweden Norway Denmark Finland Iceland], value: "Sweden"
      end
    end
  end

  def membership
    heading "Membership"
    PLANS.each do |value, label|
      radio "plan", value, checked: value == @plan, label: label
      spacer 4
    end
    spacer 8
    text "Anything we should know? (workshops you are interested in, accessibility needs)", size: 8, color: MUTED
    spacer 3
    text_field "notes", multiline: true, height: 70
  end

  def consent
    heading "Consent"
    checkbox "terms", label: "I accept the terms of membership and the workshop safety rules."
    spacer 4
    checkbox "newsletter", checked: true, label: "Send me the monthly newsletter."
    spacer 24
    row(gap: 24, align: :bottom) do
      column { signature_field "signature", label: "Signature of the applicant" }
      column(width: 150) { labelled("Date") { text_field "signed_on" } }
    end
  end
end

if $PROGRAM_NAME == __FILE__
  form = ExampleForm.preview
  form.to_pdf(File.expand_path("form.pdf", __dir__))
  warn form.warnings.map(&:message) if form.warnings.any?
  puts "wrote examples/form.pdf"
end
