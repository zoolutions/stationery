# frozen_string_literal: true

RSpec.describe "TrueType collections" do
  it "renders faces picked from one .ttc by their #N suffix" do
    path = font_path("OpenSans-Collection.ttc")
    pdf = Class.new(SpecDocument) do
      font_family "Collection", regular: "#{path}#0", bold: "#{path}#1"
      default_text font: "Collection", size: 10

      def view_template
        text "Plain"
        text "Strong", weight: :bold
      end
    end.new.to_pdf

    expect(pdf).to match(%r{/BaseFont /[A-Z]{6}\+OpenSans-Regular}).and match(%r{/BaseFont /[A-Z]{6}\+OpenSans-Bold})
    expect(text_of(pdf)).to include("Plain", "Strong")
  end
end
