# frozen_string_literal: true

require "open3"
require "tmpdir"

RSpec.describe Stationery::Forms do
  def render(&) = SpecDocument.build(&).to_pdf
  def flag?(field, bit) = field[:Ff].to_i.anybits?(1 << (bit - 1))

  # A field made without a font book, placed straight on the canvas.
  def bare(kind, name, **)
    field = Stationery::Forms::Field.new(kind, name, **)
    render { canvas(height: 30) { |canvas, rect| canvas.widget(field, rect.x, rect.y, 100, 20) } }
  end

  describe "the AcroForm" do
    let(:pdf) do
      render do
        text_field "name", value: "Ada"
        checkbox "agree"
      end
    end

    it "lists every field and the embedded font their appearances draw with as default resources" do
      form = acro_form(pdf)
      objects = form_objects(pdf)
      font = form_fonts(pdf).fetch(:F1)
      descendant = objects.deref(objects.deref(font[:DescendantFonts]).first)

      expect(objects.deref(form[:Fields]).size).to eq(2)
      expect(form[:NeedAppearances]).to be(true)
      expect(form[:DA]).to eq("/F1 0 Tf 0 g")
      expect(font).to include(Subtype: :Type0, Encoding: :"Identity-H")
      expect(font[:BaseFont].to_s).to end_with("+OpenSans-Regular")
      expect(objects.deref(descendant[:FontDescriptor])).to have_key(:FontFile2)
      expect(pdf).not_to include("Helvetica")
    end

    it "lists ZapfDingbats beside them, for the viewers it asks to redraw a button's mark" do
      buttons = render { checkbox "agree", checked: true }

      expect(form_fonts(pdf).keys).to eq(%i[F1 ZaDb])
      expect(form_fonts(pdf).fetch(:ZaDb)).to eq(Type: :Font, Subtype: :Type1, BaseFont: :ZapfDingbats)
      expect(form_fonts(buttons).keys).to eq([:ZaDb])
      expect(acro_form(buttons)).not_to have_key(:DA)
      expect(form_fonts(render { text_field "name" }).keys).to eq([:F1])
    end

    it "adds the widgets to the page's annotations, pointing back at the page" do
      page = reader_for(pdf).pages.first
      objects = form_objects(pdf)
      widgets = objects.deref(page.attributes[:Annots]).map { |ref| objects.deref(ref) }

      expect(widgets.map { |widget| widget[:Subtype] }).to eq(%i[Widget Widget])
      expect(widgets.map { |widget| widget[:P] }).to all(eq(objects.page_references.first))
      expect(widgets.map { |widget| widget[:F] }).to all(eq(4))
    end

    it "is absent from a document without fields" do
      expect(acro_form(render { text "plain" })).to be_nil
    end
  end

  describe "text fields" do
    it "writes the value, default appearance, colours and a rectangle where the layout put it" do
      pdf = render do
        text "Name"
        text_field "name", value: "Ada", width: 100, border: "#FF0000", background: "#00FF00"
      end
      field = form_fields(pdf).fetch("name")
      baseline = positions_of(pdf).first.last

      expect(field).to include(FT: :Tx, V: "Ada", DA: "/F1 10 Tf 0 g", MK: { BG: [0, 1, 0], BC: [1, 0, 0] })
      expect(field[:Rect][0]).to eq(20)
      expect(field[:Rect][2]).to eq(120)
      expect(field[:Rect][3] - field[:Rect][1]).to eq(22)
      expect(field[:Rect][3]).to be < baseline
    end

    it "fills the width by default and draws the value inside a marked-content section" do
      pdf = render { text_field "name", value: "Ada (the first)" }
      field = form_fields(pdf).fetch("name")
      stream = appearance_of(pdf, field)

      expect(field[:Rect]).to eq([20, 158, 280, 180])
      expect(stream).to include("/Tx BMC", "EMC", "/F1 10 Tf")
      expect(stream).not_to include("(Ada")
      expect(appearance_text(pdf, field)).to eq(["Ada (the first)"])
      expect(appearance_fonts(pdf, field).keys).to eq([:F1])
    end

    it "draws with the font of the text style around it" do
      pdf = render do
        text "Name"
        text_style(weight: :bold) { text_field "name", value: "Ada" }
      end
      field = form_fields(pdf).fetch("name")

      expect(field[:DA]).to eq("/F2 10 Tf 0 g")
      expect(appearance_fonts(pdf, field).fetch(:F2)[:BaseFont].to_s).to end_with("+OpenSans-Bold")
      expect(form_fonts(pdf).keys).to eq([:F2])
    end

    it "writes a value in any script the font covers as glyphs that extract as the value" do
      pdf = render { text_field "city", value: "Malmö, Αθήνα, Москва" }
      field = form_fields(pdf).fetch("city")

      expect(field[:V].b).to start_with("\xFE\xFF".b)
      expect(decode_text(field[:V])).to eq("Malmö, Αθήνα, Москва")
      expect(appearance_of(pdf, field)).to match(/<[0-9A-F]+> Tj/)
      expect(appearance_text(pdf, field)).to eq(["Malmö, Αθήνα, Москва"])
    end

    it "draws a character the font lacks with the fallback that has it" do
      pdf = render { text_field "route", value: "a → b" }
      field = form_fields(pdf).fetch("route")
      fonts = appearance_fonts(pdf, field)

      expect(fonts.values.map { |font| font[:BaseFont].to_s.split("+").last })
        .to contain_exactly("OpenSans-Regular", "Inter-Regular")
      expect(appearance_text(pdf, field).join).to eq("a → b")
      expect(form_fonts(pdf).keys).to match_array(fonts.keys)
    end

    it "reports a character no font has, as any other text does" do
      document = SpecDocument.build { text_field "odd", value: "a\u{10FFFD}" }
      document.to_pdf

      expect(document.warnings.map(&:message))
        .to eq(["missing glyph \"\u{10FFFD}\" (U+10FFFD) in Open Sans, drawn once as .notdef"])
    end

    it "sets the multiline, read-only and required flags and a maximum length" do
      pdf = render do
        text_field "notes", value: "one\ntwo", multiline: true, height: 40
        text_field "id", value: "X1", read_only: true, required: true, max_length: 8
      end
      notes, id = form_fields(pdf).values_at("notes", "id")

      expect(flag?(notes, 13)).to be(true)
      expect(appearance_text(pdf, notes)).to eq(%w[one two])
      expect([flag?(id, 1), flag?(id, 2), flag?(id, 13)]).to eq([true, true, false])
      expect(id[:MaxLen]).to eq(8)
    end

    it "wraps a long multiline value to the field's width" do
      pdf = render { text_field "notes", value: "word " * 30, multiline: true, height: 60, width: 100 }
      lines = appearance_text(pdf, form_fields(pdf).fetch("notes"))

      expect(lines.size).to be > 3
      expect(lines.join(" ")).to eq(("word " * 30).strip)
    end

    it "spreads a comb field's characters over its cells" do
      pdf = render { text_field "pin", value: "1234", comb: 4, width: 80 }
      field = form_fields(pdf).fetch("pin")
      starts = appearance_of(pdf, field).scan(/^([\d.]+) [\d.]+ Td$/).flatten.map(&:to_f)

      expect(flag?(field, 25)).to be(true)
      expect(field[:MaxLen]).to eq(4)
      expect(appearance_text(pdf, field)).to eq(%w[1 2 3 4])
      expect(starts.each_cons(2).map { |a, b| (b - a).round(3) }.uniq).to eq([20.0])
    end

    it "keeps printable ASCII and Latin-1 in the font of a field that can be edited" do
      editable = render { text_field "name", value: "Hi" }
      locked = render { text_field "name", value: "Hi", read_only: true }

      expect(characters_of(editable, form_fonts(editable).fetch(:F1))).to include("H", "i", "z", "~", "é", "ÿ")
      expect(characters_of(locked, form_fonts(locked).fetch(:F1)).delete(" ").chars).to match_array(%w[H i])
      expect(editable.bytesize).to be > locked.bytesize
    end

    it "needs a maximum length for a comb field" do
      expect { render { text_field "pin", comb: true } }.to raise_error(ArgumentError, /max_length/)
    end

    it "rejects unknown options and empty names" do
      expect { render { text_field "a", colour: "#000" } }.to raise_error(ArgumentError, /colour/)
      expect { render { text_field "" } }.to raise_error(ArgumentError, /name/)
      expect { render { text_field "a..b" } }.to raise_error(ArgumentError, /name/)
    end
  end

  describe "accessible names" do
    it "names a field after its tooltip, its label or its name" do
      pdf = render do
        text_field "applicant.name", tooltip: "Full name"
        text_field "email"
        checkbox "terms", label: "I accept the terms"
        checkbox "news"
        signature_field "signature", label: "Signature of the applicant"
      end
      names = form_fields(pdf).transform_values { |field| decode_text(field[:TU]) }

      expect(names).to eq("applicant.name" => "Full name", "email" => "email", "terms" => "I accept the terms",
                          "news" => "news", "signature" => "Signature of the applicant")
    end

    it "names a radio group after its name, or the tooltip of its first choice" do
      plain = render { radio("plan", "basic", label: "Basic") && radio("plan", "pro", label: "Pro") }
      named = render { radio("plan", "basic", tooltip: "Membership plan") && radio("plan", "pro") }

      expect(decode_text(form_fields(plain).fetch("plan")[:TU])).to eq("plan")
      expect(decode_text(form_fields(named).fetch("plan")[:TU])).to eq("Membership plan")
      expect(form_fields(plain).fetch("plan")[:Kids]).to all(satisfy { |kid| !kid.key?(:TU) })
    end
  end

  describe "checkboxes" do
    it "writes on and off appearances and selects the one its state names" do
      pdf = render do
        checkbox "yes", checked: true
        checkbox "no", size: 16
      end
      checked, unchecked = form_fields(pdf).values_at("yes", "no")

      expect(checked).to include(FT: :Btn, V: :Yes, AS: :Yes)
      expect(unchecked).to include(V: :Off, AS: :Off)
      expect(checked).not_to have_key(:DA)
      expect(unchecked[:Rect][2] - unchecked[:Rect][0]).to eq(16)
    end

    it "strokes the check mark as a path, without any font" do
      pdf = render { checkbox "yes", checked: true }
      field = form_fields(pdf).fetch("yes")
      mark = appearance_of(pdf, field, :Yes).delete_prefix(appearance_of(pdf, field, :Off))

      expect(mark).to eq("q\n0 0 0 RG\n1.152 w\n1 J\n1 j\n3.312 5.808 m\n5.232 3.888 l\n8.688 8.112 l\nS\nQ\n")
      expect(appearance_of(pdf, field, :Off)).not_to include(" l\nS")
      expect(appearance_fonts(pdf, field, :Yes)).to eq({})
      expect(appearance_of(pdf, field, :Yes)).not_to include("Tf", "Tj")
    end

    it "draws its label as text beside the box" do
      pdf = render { checkbox "agree", label: "I agree" }
      box = form_fields(pdf).fetch("agree")[:Rect]

      expect(text_of(pdf)).to include("I agree")
      expect(positions_of(pdf).first.first).to be > box[2]
    end
  end

  describe "radio groups" do
    let(:pdf) do
      render do
        radio "plan", "basic", label: "Basic"
        radio "plan", "pro", checked: true, label: "Pro"
        radio "plan", "team", label: "Team"
      end
    end

    it "makes one parent field with the radio flag, the checked value and a widget per choice" do
      plan = form_fields(pdf).fetch("plan")

      expect(plan).to include(FT: :Btn, V: :pro)
      expect([flag?(plan, 16), flag?(plan, 15)]).to eq([true, true])
      expect(plan[:Kids].map { |kid| kid[:AS] }).to eq(%i[Off pro Off])
      expect(plan[:Kids].map { |kid| kid[:MK][:CA] }).to all(eq("l"))
    end

    it "draws a dot for the on state only and labels each choice" do
      kid = form_fields(pdf).fetch("plan")[:Kids].first

      expect(appearance_of(pdf, kid, :basic).scan(/ c$/).size).to be > appearance_of(pdf, kid, :Off).scan(/ c$/).size
      expect(appearance_fonts(pdf, kid, :basic)).to eq({})
      expect(text_of(pdf)).to include("Basic", "Pro", "Team")
    end

    it "is Off when nothing is checked" do
      pdf = render { radio "size", "s" }

      expect(form_fields(pdf).fetch("size")).to include(V: :Off)
    end
  end

  describe "select boxes" do
    it "writes a combo box with its options, value and an appearance showing the value" do
      pdf = render { select "country", options: %w[Sweden Norway Österreich], value: "Norway", width: 120 }
      field = form_fields(pdf).fetch("country")

      expect(field).to include(FT: :Ch, V: "Norway", DA: "/F1 10 Tf 0 g")
      expect(field[:Opt].map { |option| decode_text(option) }).to eq(%w[Sweden Norway Österreich])
      expect([flag?(field, 18), flag?(field, 19)]).to eq([true, false])
      expect(appearance_of(pdf, field)).to include("/Tx BMC")
      expect(appearance_text(pdf, field)).to eq(["Norway"])
    end

    it "keeps the glyphs of every option, so choosing another one can be drawn" do
      pdf = render { select "city", options: %w[Lund Αθήνα], value: "Lund" }
      locked = render { select "city", options: %w[Lund Αθήνα], value: "Lund", read_only: true }

      expect(characters_of(pdf, form_fonts(pdf).fetch(:F1))).to include("Α", "θ", "ή", "ν", "α")
      expect(characters_of(locked, form_fonts(locked).fetch(:F1)).delete(" ").chars).to match_array(%w[L u n d])
    end

    it "adds the edit flag when editable and leaves the value out when none is chosen" do
      pdf = render { select "city", options: %w[Lund Malmö], editable: true }
      field = form_fields(pdf).fetch("city")

      expect(flag?(field, 19)).to be(true)
      expect(field).not_to have_key(:V)
    end
  end

  describe "signature fields" do
    it "draws only the rule without a label" do
      pdf = render { signature_field "signature", label: "" }
      field = form_fields(pdf).fetch("signature")

      expect(appearance_of(pdf, field)).not_to include("Tj")
      expect(decode_text(field[:TU])).to eq("signature")
    end

    it "writes an empty /Sig field whose appearance draws a rule and the label" do
      pdf = render { signature_field "signature", width: 180, label: "Sökandens underskrift" }
      field = form_fields(pdf).fetch("signature")

      expect(field).to include(FT: :Sig)
      expect(field).not_to have_key(:V)
      expect(field).not_to have_key(:DA)
      expect(field[:Rect][3] - field[:Rect][1]).to eq(40)
      expect(appearance_of(pdf, field)).to include("/F1 7 Tf", "l\nS")
      expect(appearance_text(pdf, field)).to eq(["Sökandens underskrift"])
    end
  end

  describe "a field without a font book" do
    it "draws with the standard Helvetica in Windows-1252" do
      pdf = bare(:text, "raw", value: "Malmö → Lund")
      field = form_fields(pdf).fetch("raw")

      expect(field).to include(DA: "/Helv 10 Tf 0 g", TU: "raw")
      expect(appearance_of(pdf, field)).to include("/Helv 10 Tf", "(Malm\xF6 ? Lund) Tj".b)
      expect(form_fonts(pdf)).to eq(Helv: { Type: :Font, Subtype: :Type1, BaseFont: :Helvetica,
                                            Encoding: :WinAnsiEncoding })
      expect(acro_form(pdf)[:DA]).to eq("/Helv 0 Tf 0 g")
    end

    it "lists Helvetica beside the embedded fonts of the other fields" do
      field = Stationery::Forms::Field.new(:text, "raw", value: "x")
      pdf = render do
        text_field "name", value: "Ada"
        canvas(height: 30) { |canvas, rect| canvas.widget(field, rect.x, rect.y, 100, 20) }
      end

      expect(form_fonts(pdf).keys).to contain_exactly(:F1, :Helv)
    end

    it "needs no font for a check box" do
      pdf = bare(:checkbox, "raw", value: true)
      field = form_fields(pdf).fetch("raw")

      expect(form_fonts(pdf).keys).to eq([:ZaDb])
      expect(appearance_fonts(pdf, field, :Yes)).to eq({})
      expect(appearance_of(pdf, field, :Yes)).to include(" l\nS")
    end
  end

  it "reports radios, selects and signatures in the document's fields" do
    document = SpecDocument.build do
      radio "plan", "basic"
      radio "plan", "pro", checked: true
      radio "size", "s"
      select "country", options: %w[SE NO], value: "NO"
      signature_field "sig"
    end
    document.to_pdf

    expect(document.fields).to eq("plan" => "pro", "size" => nil, "country" => "NO", "sig" => nil)
  end

  it "groups dotted names under parent fields" do
    pdf = render do
      text_field "address.city", value: "Lund"
      text_field "address.zip", value: "22100"
      text_field "email"
    end
    objects = form_objects(pdf)
    roots = objects.deref(acro_form(pdf)[:Fields]).map { |ref| objects.deref(ref) }
    address = roots.find { |root| root[:T] == "address" }

    expect(roots.map { |root| root[:T] }).to contain_exactly("address", "email")
    expect(address).not_to have_key(:TU)
    expect(objects.deref(address[:Kids]).map { |ref| objects.deref(ref)[:T] }).to eq(%w[city zip])
    expect(form_fields(pdf).keys).to contain_exactly("address.city", "address.zip", "email")
  end

  it "refuses a name that is both a field and a group, or shared by different kinds" do
    expect { render { text_field("a") && text_field("a.b") } }.to raise_error(ArgumentError, /"a" is both/)
    expect { render { text_field("a") && checkbox("a") } }.to raise_error(ArgumentError, /different kinds/)
  end

  it "makes widgets sharing a name kids of one field" do
    pdf = render do
      text_field "email", value: "a@b.se"
      text_field "email", value: "a@b.se"
    end
    field = form_fields(pdf).fetch("email")

    expect(field[:V]).to eq("a@b.se")
    expect(field[:Kids].map { |kid| kid[:Subtype] }).to eq(%i[Widget Widget])
    expect(field[:Kids].map { |kid| kid[:Rect][1] }.uniq.size).to eq(2)
  end

  it "places a field at a fixed position outside the flow" do
    pdf = render do
      text_field "floating", at: [150, 100], width: 60
      text "in flow"
    end

    expect(form_fields(pdf).fetch("floating")[:Rect]).to eq([150, 78, 210, 100])
    expect(positions_of(pdf).first.first).to eq(20)
  end

  it "works inside a table cell" do
    pdf = render { table([["Name", -> { text_field "name", value: "Ada" }]], width: :full, widths: [100, nil]) }

    expect(form_fields(pdf).fetch("name")[:Rect][0]).to be > 100
  end

  it "outlines fields in debug mode" do
    pdf = SpecDocument.build { text_field "name" }.to_pdf(debug: [:field])

    expect(page_contents(pdf).first).to include(Stationery::Color.parse("#7C3AED").stroke)
  end

  it "keeps field values readable in an encrypted document" do
    encrypt = { user_password: "pw", owner_password: "owner" }
    pdf = SpecDocument.build { text_field "name", value: "Müller" }.to_pdf(encrypt:)

    expect(pdf).not_to include("/F1 10 Tf")
    expect(decode_text(form_fields(pdf, password: "pw").fetch("name")[:V])).to eq("Müller")
  end

  it "lists the document's fields and their values after rendering" do
    document = SpecDocument.build do
      text_field "name", value: "Ada"
      checkbox "agree", checked: true
      checkbox "news"
    end

    expect(document.fields).to be_nil
    document.to_pdf
    expect(document.fields).to eq("name" => "Ada", "agree" => true, "news" => false)
  end

  it "renders with mutool", skip: (system("mutool -v", out: File::NULL, err: File::NULL) ? false : "no mutool") do
    pdf = render do
      text_field "name", value: "Ada"
      checkbox "agree", checked: true
    end
    Dir.mktmpdir do |dir|
      File.binwrite(File.join(dir, "form.pdf"), pdf)
      output, status = Open3.capture2e("mutool", "draw", "-o", File.join(dir, "out.png"), File.join(dir, "form.pdf"))

      expect(status).to be_success
      expect(output).not_to match(/error|warning/i)
    end
  end
end
