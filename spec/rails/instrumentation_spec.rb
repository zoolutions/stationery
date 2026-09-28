# frozen_string_literal: true

require_relative "spec_helper"

RSpec.describe Stationery::Instrumentation do
  let(:events) { [] }

  before { Stationery.instrumenter = nil }
  after { Stationery.instrumenter = nil }

  it "uses ActiveSupport::Notifications when it is loaded" do
    expect(Stationery.instrumenter).to be(ActiveSupport::Notifications)
  end

  it "delivers the finished payload to subscribers" do
    subscriber = ActiveSupport::Notifications.subscribe(/\.stationery\z/) do |name, start, finish, _id, payload|
      events << [name, finish - start, payload]
    end
    pdf = SpecDocument.build { text "hi" }.to_pdf

    names = events.map(&:first)
    render = events.find { |name, _, _| name == "render.stationery" }
    expect(names).to include("build.stationery", "paginate.stationery", "write.stationery", "font.stationery")
    expect(names.last).to eq("render.stationery")
    expect(render[1]).to be >= 0
    expect(render[2]).to include(pages: 1, bytes: pdf.bytesize, warnings: 0)
    expect(render[2]).to have_key(:document)
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end
end
