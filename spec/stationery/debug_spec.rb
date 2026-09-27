# frozen_string_literal: true

RSpec.describe "Debug outlines" do # rubocop:disable RSpec/DescribeClass
  let(:colors) do
    { box: "#E11D48", column: "#2563EB", cell: "#16A34A", flow: "#9CA3AF", positioned: "#DB2777",
      image: "#0D9488", page: "#06B6D4" }.transform_values { |hex| Stationery::Color.parse(hex).stroke }
  end
  let(:photo) { image_path("rgb.jpg") }
  let(:document) do
    path = photo
    SpecDocument.build do
      box(padding: 4) { text "Boxed" }
      row do
        column { text "Left" }
        column { text "Right" }
      end
      table([%w[a b]])
      image(path, width: 10)
      box(at: [200, 10], width: 40) { text "Floating" }
    end
  end

  def content(**) = page_contents(document.to_pdf(**)).join

  it "outlines every kind of layout rectangle with debug: true" do
    pdf = document.to_pdf(debug: true)

    expect(page_contents(pdf).join).to include(*colors.values, "[2 2] 0 d", "[1 2] 0 d")
    expect(reader_for(pdf).page_count).to eq(1)
  end

  it "outlines only the listed kinds" do
    ops = content(debug: %i[cell])

    expect(ops).to include(colors[:cell])
    expect(ops).not_to include(*colors.except(:cell).values)
  end

  it "draws no outlines by default" do
    ops = content

    colors.each_value { |stroke| expect(ops).not_to include(stroke) }
  end
end
