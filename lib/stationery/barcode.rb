# frozen_string_literal: true

module Stationery
  # Barcodes, encoded in pure Ruby and drawn as vector bars and squares
  # (the `barcode` element): Code 128, EAN-13 and QR Code. A symbol answers
  # `linear?`, `quiet` (its quiet zone in modules) and `zpl`, the command a
  # label printer draws it with; a linear one `width` (modules) and `bars`
  # ([first module, modules wide]), a QR code `size` and `modules`.
  module Barcode
    TYPES = { code128: "Code128", ean13: "EAN13", qr: "QR" }.freeze

    module_function

    # The symbol of `type` for `data`; `level:` is a QR code's.
    def build(type, data, level: nil)
      name = TYPES.fetch(type) do
        raise ArgumentError, "barcode type: is :code128, :ean13 or :qr, not #{type.inspect}"
      end
      raise ArgumentError, "level: is for a QR code" if level && type != :qr

      type == :qr ? QR.new(data, level: level || :m) : const_get(name).new(data)
    end

    # ^FD with `text`, then ^FS; ^FH first when `text` has a byte ZPL would
    # read as a command or that is not ASCII, each such byte written as \XX.
    def field(text)
      text = text.b
      return "^FD#{text}^FS" unless text.match?(/[\^~\\\x00-\x1F\x7F-\xFF]/n)

      "^FH\\^FD#{text.gsub(/[\^~\\\x00-\x1F\x7F-\xFF]/n) { |byte| format("\\%02X", byte.ord) }}^FS"
    end
  end
end
