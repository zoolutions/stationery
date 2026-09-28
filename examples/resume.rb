# frozen_string_literal: true

# A one-page résumé in two columns of unequal width: a tinted sidebar with
# contact links and skills, and the experience written as HTML, the way it
# comes out of a rich-text editor. Run it to write examples/resume.pdf:
#
#   ruby -Ilib examples/resume.rb
#   ruby -Ilib exe/stationery render examples/resume.rb
require "stationery"

class ExampleResume < Stationery::Document
  ACCENT = "#2563EB"
  INK = "#111827"
  MUTED = "#6B7280"
  SIDEBAR = "#F1F5F9"

  # What the person wrote in the application's editor: `html` reads it with
  # the styles given below, and turns its links into links.
  EXPERIENCE = <<~HTML
    <style>.when { color: #6B7280; font-size: 8.5pt }</style>
    <h2>Profile</h2>
    <p>Engineer who likes the unglamorous parts of logistics software: the queues, the retries and the
    documents at the end of them. Ten years of Ruby, most of them with a pager.</p>
    <h2>Experience</h2>
    <h3>Lead engineer · Harbour Logistics, Gothenburg</h3>
    <p class="when">2022 – today</p>
    <p>Leads a team of six building the routing platform that plans 40,000 deliveries a day.</p>
    <ul>
      <li>Moved route planning from a nightly batch to <b>live replanning</b>, cutting late deliveries by a third.</li>
      <li>Introduced contract tests between the eleven services the platform is made of.</li>
      <li>Mentors two engineers a year through the company's <a href="https://harbour-logistics.example/graduates">graduate programme</a>.</li>
    </ul>
    <h3>Software engineer · Northwind Freight, Malmö</h3>
    <p class="when">2018 – 2022</p>
    <p>Built the customer portal and the <i>proof of delivery</i> service, from the first commit to
    two million documents a month.</p>
    <ul>
      <li>Replaced a PDF service in Java with one in Ruby that renders in a tenth of the time.</li>
      <li>Ran the on-call rotation for the portal and wrote its runbooks.</li>
    </ul>
    <h3>Junior developer · Example Studio, Lund</h3>
    <p class="when">2016 – 2018</p>
    <p>Web shops and booking systems for small businesses in southern Sweden.</p>
    <h2>Education</h2>
    <h3>MSc Computer Science · Lund University</h3>
    <p class="when">2011 – 2016</p>
    <p>Thesis on incremental layout of long documents, graded with distinction.</p>
  HTML

  STYLES = {
    h2: { size: 13, color: ACCENT }, h3: { size: 10.5 }, p: { color: INK },
    a: { color: ACCENT }, ul: { gap: 3, marker_color: ACCENT }
  }.freeze

  page size: :a4, margin: [44, 44, 40, 44]
  default_text size: 9.5, color: INK, leading: 2
  metadata title: "Résumé of Kim Example", author: "Kim Example", creator: "stationery example"

  def self.preview
    new(name: "Kim Example", title: "Lead software engineer",
        contact: [["kim@example.com", "mailto:kim@example.com"], ["+46 70 000 00 00", "tel:+46700000000"],
                  ["kim.example.com", "https://kim.example.com"], ["Gothenburg, Sweden", nil]],
        skills: %w[Ruby Rails PostgreSQL Kafka Kubernetes Terraform TypeScript],
        languages: [%w[Swedish native], %w[English fluent], %w[German good]])
  end

  def initialize(name:, title:, contact:, skills:, languages:)
    super()
    @name = name
    @title = title
    @contact = contact
    @skills = skills
    @languages = languages
  end

  def view_template
    text @name, size: 28, weight: :bold
    text @title, size: 12, color: ACCENT
    spacer 18
    # A sidebar of 30 % and a body that takes the rest: `width:` is a share
    # of the row, and a column without one takes what is left.
    row(gap: 24) do
      column(width: 0.3) { sidebar }
      column { html EXPERIENCE, styles: STYLES, gap: 5 }
    end
  end

  private

  def sidebar
    box(background: SIDEBAR, radius: 6, padding: 14) do
      label "CONTACT"
      @contact.each do |shown, target|
        text shown, link: target, color: target ? ACCENT : INK, size: 9
        spacer 2
      end
      spacer 12
      label "SKILLS"
      wrap(gap: 4, row_gap: 4) do
        @skills.each { |skill| box(width: :auto, background: "#FFFFFF", radius: 8, padding: [2, 7]) { text skill, size: 8 } }
      end
      spacer 12
      label "LANGUAGES"
      @languages.each { |language, level| text "<b>#{language}</b>, #{level}", markup: true, size: 9 }
    end
  end

  def label(title)
    text title, size: 7.5, weight: :bold, color: MUTED, letter_spacing: 0.8
    spacer 5
  end
end

if $PROGRAM_NAME == __FILE__
  resume = ExampleResume.preview
  resume.to_pdf(File.expand_path("resume.pdf", __dir__))
  warn resume.warnings.map(&:message) if resume.warnings.any?
  puts "wrote examples/resume.pdf"
end
