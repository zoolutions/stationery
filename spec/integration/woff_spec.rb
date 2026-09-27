# frozen_string_literal: true

RSpec.describe "WOFF web fonts" do
  it "renders text set in a .woff font" do
    path = font_path("OpenSans-Regular.woff")
    pdf = Class.new(SpecDocument) do
      font_family "Web", regular: path
      default_text font: "Web", size: 10

      def view_template = text("Hello from the web")
    end.new.to_pdf

    expect(pdf).to match(%r{/BaseFont /[A-Z]{6}\+OpenSans-Regular})
    expect(text_of(pdf)).to include("Hello from the web")
  end
end
