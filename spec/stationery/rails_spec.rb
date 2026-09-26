# frozen_string_literal: true

require "stationery/rails"

RSpec.describe Stationery::Rails do
  let(:controller) do
    Class.new do
      include Stationery::Rails

      attr_reader :sent

      def send_data(data, **options) = @sent = [data, options]
    end.new
  end

  it "sends the rendered PDF inline by default" do
    controller.send_pdf(SpecDocument.build { text "x" }, filename: "x.pdf")
    data, options = controller.sent

    expect(data).to start_with("%PDF")
    expect(options).to eq(type: "application/pdf", disposition: "inline", filename: "x.pdf")
  end

  it "passes disposition and other options through" do
    controller.send_pdf(SpecDocument.build { text "x" }, disposition: "attachment", filename: "a.pdf", status: 201)

    expect(controller.sent.last).to include(disposition: "attachment", status: 201)
  end
end
