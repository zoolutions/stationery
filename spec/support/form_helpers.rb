# frozen_string_literal: true

require "delegate"
require "stringio"
require "stationery/testing/inspector"

module FormHelpers
  UTF16_BOM = "\xFE\xFF".b

  # A form XObject in place of the page it is on, so that the receiver the
  # Inspector reads a page with reads the form alone.
  class FormAlone < SimpleDelegator
    def initialize(page, stream)
      super(page)
      @form = PDF::Reader::FormXObject.new(page, stream)
    end

    def fonts = @form.fonts
    def xobjects = @form.xobjects
    def walk(*) = @form.walk(*)
  end

  def form_objects(pdf, password: "") = PDF::Reader.new(StringIO.new(pdf), password:).objects

  # The catalog's /AcroForm dictionary, or nil.
  def acro_form(pdf, password: "")
    objects = form_objects(pdf, password:)
    objects.deref(objects.deref(objects.trailer[:Root])[:AcroForm])
  end

  # The form's default resources: { name => font dictionary }.
  def form_fonts(pdf)
    objects = form_objects(pdf)
    fonts = objects.deref(objects.deref(acro_form(pdf)[:DR])[:Font])
    fonts.transform_values { |ref| objects.deref(ref) }
  end

  # Every terminal field by its full dotted name. Each is the field's
  # dictionary with :Kids replaced by its widget dictionaries (a field merged
  # with its widget lists itself as its only widget).
  def form_fields(pdf, password: "")
    objects = form_objects(pdf, password:)
    form = objects.deref(objects.deref(objects.trailer[:Root])[:AcroForm])
    collect_fields(objects, form[:Fields], nil)
  end

  def decode_text(value)
    return value.dup.force_encoding(Encoding::UTF_8) unless value.b.start_with?(UTF16_BOM)

    value.b.byteslice(2..).force_encoding(Encoding::UTF_16BE).encode(Encoding::UTF_8)
  end

  # The decompressed normal appearance of a widget, or of its `state`.
  def appearance_of(pdf, widget, state = nil) = appearance_stream(form_objects(pdf), widget, state).unfiltered_data

  # The font resources of a widget's normal appearance: { name => dictionary }.
  def appearance_fonts(pdf, widget, state = nil)
    objects = form_objects(pdf)
    resources = objects.deref(appearance_stream(objects, widget, state).hash[:Resources]) || {}
    (objects.deref(resources[:Font]) || {}).transform_values { |ref| objects.deref(ref) }
  end

  # The strings a widget's normal appearance shows, one for each operator
  # that shows any: decoded through its fonts, a sequence with ActualText as
  # that text.
  def appearance_text(pdf, widget, state = nil)
    reader = PDF::Reader.new(StringIO.new(pdf))
    form = FormAlone.new(reader.pages.first, appearance_stream(reader.objects, widget, state))
    Stationery::Testing::MarkedText.read(form).shown
  end

  # The characters a font's ToUnicode map covers: what its subset can show.
  def characters_of(pdf, font)
    cmap = PDF::Reader::CMap.new(form_objects(pdf).deref(font[:ToUnicode]).unfiltered_data)
    cmap.map.values.flatten.pack("U*")
  end

  private

  def appearance_stream(objects, widget, state)
    normal = objects.deref(objects.deref(widget[:AP])[:N])
    state ? objects.deref(normal[state]) : normal
  end

  def collect_fields(objects, refs, prefix)
    Array(objects.deref(refs)).each_with_object({}) do |ref, fields|
      field = objects.deref(ref)
      name = [prefix, decode_text(field[:T])].compact.join(".")
      kids = Array(objects.deref(field[:Kids])).map { |kid| objects.deref(kid) }
      if kids.any? { |kid| kid.key?(:T) }
        fields.merge!(collect_fields(objects, field[:Kids], name))
      else
        fields[name] = field.merge(Kids: kids.empty? ? [field] : kids)
      end
    end
  end
end

RSpec.configure { |config| config.include FormHelpers }
