# frozen_string_literal: true

module Stationery
  module PDF
    # Turns Ruby values into PDF object syntax.
    #
    # A plain String is always written as a literal byte string `( … )` — never
    # re-encoded — so a URI stays the 7-bit ASCII the spec requires. Use
    # TextString for human-readable text that may need UTF-16.
    #
    # `crypt`, when given, receives every string's bytes (the writer binds it
    # to the object being written) and the result is written as hex. A
    # Verbatim is written as it is.
    module Serializer
      NAME_ESCAPE = %r{[^\x21-\x7E]|[#%()/<>\[\]{}]}n
      LITERAL_ESCAPE = /[\\()\r]/n
      UTF16_BOM = "\xFE\xFF".b

      module_function

      def dump(value, crypt = nil)
        case value
        when Reference then "#{value.id} 0 R"
        when Symbol then name(value)
        when Hash then "<<#{value.map { |k, v| "#{name(k)} #{dump(v, crypt)}" }.join(" ")}>>"
        when Array then "[#{value.map { |v| dump(v, crypt) }.join(" ")}]"
        when HexString then hex(value.bytes, crypt)
        when TextString then text(value.value, crypt)
        when Verbatim then value.source
        when String then crypt ? hex(value, crypt) : literal(value)
        when Integer, true, false then value.to_s
        when Float then number(value)
        when nil then "null"
        else raise ArgumentError, "cannot serialize #{value.class} to PDF"
        end
      end

      def name(value)
        "/#{value.to_s.b.gsub(NAME_ESCAPE) { |c| format("#%02X", c.ord) }}"
      end

      def literal(value)
        "(#{value.b.gsub(LITERAL_ESCAPE) { |c| c == "\r" ? "\\r" : "\\#{c}" }})"
      end

      def hex(bytes, crypt = nil)
        bytes = crypt.call(bytes.b) if crypt
        "<#{bytes.unpack1("H*").upcase}>"
      end

      def number(value)
        return value.to_s if value.is_a?(Integer)

        str = format("%.4f", value)
        last = str.bytesize
        last -= 1 while str.getbyte(last - 1) == 48 # "0"
        last -= 1 if str.getbyte(last - 1) == 46 # "."
        str = str.byteslice(0, last)
        str == "-0" ? "0" : str
      end

      def text(value, crypt = nil)
        value = value.to_s
        return dump(value, crypt) if value.ascii_only?

        hex(UTF16_BOM + value.encode(Encoding::UTF_16BE).b, crypt)
      end
    end
  end
end
