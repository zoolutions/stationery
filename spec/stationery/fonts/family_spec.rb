# frozen_string_literal: true

RSpec.describe Stationery::Fonts::Family do
  let(:full) do
    described_class.new(
      "Open Sans",
      regular: font_path("OpenSans-Regular.ttf"),
      bold: font_path("OpenSans-Bold.ttf"),
      italic: font_path("OpenSans-Italic.ttf"),
      bold_italic: font_path("OpenSans-BoldItalic.ttf")
    )
  end

  it "resolves each declared style to its own file" do
    expect(full.face(weight: :bold, style: :italic).path).to end_with("OpenSans-BoldItalic.ttf")
    expect(full.face(weight: :regular, style: :normal).path).to end_with("OpenSans-Regular.ttf")
  end

  it "synthesises bold and oblique when a family lacks those files" do
    regular_only = described_class.new("Inter", regular: font_path("Inter-Regular.ttf"))
    face = regular_only.face(weight: :bold, style: :italic)

    expect(face.path).to end_with("Inter-Regular.ttf")
    expect(face).to have_attributes(synthetic_bold: true, synthetic_oblique: true)
  end

  it "prefers a real bold over synthesising from regular for bold italic" do
    no_bold_italic = described_class.new("OS", regular: font_path("OpenSans-Regular.ttf"),
                                               bold: font_path("OpenSans-Bold.ttf"))
    face = no_bold_italic.face(weight: :bold, style: :italic)

    expect(face.path).to end_with("OpenSans-Bold.ttf")
    expect(face).to have_attributes(synthetic_bold: false, synthetic_oblique: true)
  end

  it "requires a regular face and rejects unknown styles" do
    expect { described_class.new("X", bold: font_path("OpenSans-Bold.ttf")) }.to raise_error(ArgumentError, /regular/)
    expect { described_class.new("X", regular: font_path("OpenSans-Regular.ttf"), heavy: "x") }
      .to raise_error(ArgumentError, /heavy/)
  end
end
