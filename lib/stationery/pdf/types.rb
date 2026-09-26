# frozen_string_literal: true

module Stationery
  module PDF
    # An indirect object reference: `12 0 R`.
    Reference = Data.define(:id)

    # Bytes written in hex form: `<48656C6C6F>`.
    HexString = Data.define(:bytes)

    # A human-readable string (document info, outline titles): written as a
    # literal when ASCII, as UTF-16BE with a byte order mark otherwise.
    TextString = Data.define(:value)
  end
end
