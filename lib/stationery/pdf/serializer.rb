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
      # Below it a Float times 10,000 is off by less than TIE / 8, so which
      # way it rounds is certain unless it is within TIE of a half.
      FAST_BELOW = 100_000.0
      TIE = 1e-6

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

      # Four decimals with the zeros after them trimmed. A Float below
      # FAST_BELOW, which a coordinate is, is rounded here and written from
      # its digits, one String and no `format`; what is left goes through
      # `format`, which is what decides how all of them are written.
      def number(value)
        return value.to_s if value.is_a?(Integer)
        return formatted(value) unless value.is_a?(Float) && value.abs < FAST_BELOW

        scaled = value.abs * 10_000.0
        units = scaled.floor
        rest = scaled - units
        return formatted(value) if (rest - 0.5).abs < TIE

        units += 1 if rest > 0.5
        digits(units, value.negative?)
      end

      # `units` ten-thousandths as a decimal number.
      def digits(units, negative)
        return +"0" if units.zero?

        whole = units / 10_000
        str = negative ? signed(whole) : whole.to_s
        str.force_encoding(Encoding::UTF_8)
        rest = units % 10_000
        return str if rest.zero?

        str << "."
        place = 1000
        while rest.positive?
          str << (48 + (rest / place)) # "0"
          rest %= place
          place /= 10
        end
        str
      end

      def signed(whole) = whole.zero? ? +"-0" : (-whole).to_s

      def formatted(value)
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
