# frozen_string_literal: true

# The documents spec/integration/ractor_canary_spec.rb and contention_spec.rb
# render, finalized at boot as an app would (Stationery::Document.finalize!),
# so any Ractor can render them: text, a shape, an embedded JPEG, a table,
# a barcode and a footer, over three pages.
module CanaryDocuments
  JPEG = File.expand_path("../fixtures/images/rgb.jpg", __dir__).freeze
  # The clock a render reads while `Thread.current[:stationery_pinned_clock]`
  # is set, the same in every Ractor, so two renders are the same bytes
  # whenever the second turns (AGENTS.md).
  NOW = Time.utc(2026, 1, 1, 12).freeze

  module PinnedClock
    def now(*) = Thread.current[:stationery_pinned_clock] ? NOW : super
  end
  Time.singleton_class.prepend(PinnedClock)

  # Bundled Inter, parsed and made Ractor-shareable: a parse a Ractor is
  # handed as it is, not copied.
  def self.shared_font
    Ractor.make_shareable(Stationery::Fonts::TrueType.new(File.binread(File.join(Stationery::Fonts::Bundled::DIR,
                                                                                 "Inter-Regular.ttf"))))
  end

  # The block's result with the clock pinned, in whichever Ractor runs it.
  def self.pinned
    Thread.current[:stationery_pinned_clock] = true
    yield
  ensure
    Thread.current[:stationery_pinned_clock] = nil
  end

  Report = Class.new(Stationery::Document) do
    page size: :a6, margin: 24
    metadata title: "Canary", lang: "en"
    default_text size: 9, hyphenate: :en
    footer { |page| text "#{page.number} of #{page.count}", size: 7, align: :right }

    def view_template
      3.times do |index|
        text "Section #{index + 1}", size: 14, weight: :bold, color: "#1F2937"
        text "The quick brown fox jumps over the lazy dog, a hyphenation of considerable length. " * 3
        canvas(height: 36) do |c|
          c.rounded_rect(0, 0, 90, 30, radius: 4, fill: "#C2410C")
          c.circle(120, 15, 12, stroke: "#1D4ED8", line_width: 2)
        end
        image JPEG, width: 60
        table [%w[Item Qty], ["Paper", (index + 1).to_s]], header: true, cell: { padding: 4 }
        barcode "https://stationery.zoolutions.llc/#{index}", type: :qr, module_size: 2
        page_break if index < 2
      end
    end
  end.finalize!
end
