# frozen_string_literal: true

require "stringio"

module FormHelpers
  UTF16_BOM = "\xFE\xFF".b

  def form_objects(pdf, password: "") = PDF::Reader.new(StringIO.new(pdf), password:).objects

  # The catalog's /AcroForm dictionary, or nil.
  def acro_form(pdf, password: "")
    objects = form_objects(pdf, password:)
    objects.deref(objects.deref(objects.trailer[:Root])[:AcroForm])
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
  def appearance_of(pdf, widget, state = nil)
    objects = form_objects(pdf)
    normal = objects.deref(objects.deref(widget[:AP])[:N])
    normal = objects.deref(normal[state]) if state
    normal.unfiltered_data
  end

  private

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
