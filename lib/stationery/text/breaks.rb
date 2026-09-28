# frozen_string_literal: true

module Stationery
  module Text
    # Where a line may break inside a word: between two ideographic
    # characters (UAX #14 class ID: CJK ideographs, kana, Hangul, fullwidth
    # forms), never before a closing mark or a character that must not start
    # a line (、。」ー and the small kana: classes CL, CP, EX and NS), never
    # after an opening bracket (「（: class OP). A word is cut into units at
    # those points; Latin text stays one unit, so its breaking is unchanged.
    module Breaks
      ZERO_WIDTH_SPACE = "​"

      IDEOGRAPHIC = [
        0x1100..0x11FF,   # Hangul Jamo
        0x2E80..0x2FDF,   # CJK radicals
        0x3005..0x3007,   # 々 〆 〇
        0x3021..0x3029,   # Hangzhou numerals
        0x3031..0x3035,   # kana repeat marks
        0x3038..0x303C,
        0x3041..0x309A,   # Hiragana (the small kana are taken out below)
        0x30A1..0x30FA,   # Katakana
        0x3100..0x312F,   # Bopomofo
        0x3130..0x318F,   # Hangul compatibility Jamo
        0x3190..0x31FF,   # Kanbun, Bopomofo extended, CJK strokes, Katakana phonetic extensions
        0x3200..0x33FF,   # enclosed CJK, CJK compatibility
        0x3400..0x4DBF,   # CJK extension A
        0x4E00..0x9FFF,   # CJK unified ideographs
        0xA000..0xA4CF,   # Yi
        0xA960..0xA97F,   # Hangul Jamo extended A
        0xAC00..0xD7AF,   # Hangul syllables
        0xF900..0xFAFF,   # CJK compatibility ideographs
        0xFE30..0xFE4F,   # CJK compatibility forms
        0xFF10..0xFF19,   # fullwidth digits
        0xFF21..0xFF3A, 0xFF41..0xFF5A, # fullwidth Latin
        0xFF66..0xFF6F, 0xFF71..0xFF9D, # halfwidth Katakana (ｰ and the small ones are NS)
        0x1B000..0x1B16F, # Kana supplement and extended
        0x20000..0x3134F  # CJK extensions B–G
      ].freeze

      # Never at the start of a line: closing brackets and quotes, sentence
      # and clause punctuation, prolonged sound and iteration marks, small kana.
      CLOSING = [
        0x3001..0x3003, 0x3009, 0x300B, 0x300D, 0x300F, 0x3011, 0x3015, 0x3017, 0x3019, 0x301B, 0x301C,
        0x301F, 0x303B, 0x309B..0x309E, 0x30A0, 0x30FB..0x30FE,
        0x3041, 0x3043, 0x3045, 0x3047, 0x3049, 0x3063, 0x3083, 0x3085, 0x3087, 0x308E, 0x3095, 0x3096,
        0x30A1, 0x30A3, 0x30A5, 0x30A7, 0x30A9, 0x30C3, 0x30E3, 0x30E5, 0x30E7, 0x30EE, 0x30F5, 0x30F6,
        0x31F0..0x31FF,
        0xFE50..0xFE52, 0xFE54..0xFE57, 0xFE5A, 0xFE5C, 0xFE5E,
        0xFF01, 0xFF09, 0xFF0C, 0xFF0E, 0xFF1A, 0xFF1B, 0xFF1F, 0xFF3D, 0xFF5D, 0xFF60, 0xFF61, 0xFF63,
        0xFF64, 0xFF65, 0xFF67..0xFF6F, 0xFF70, 0xFF9E, 0xFF9F,
        0x2025, 0x2026
      ].freeze

      # Never at the end of a line: opening brackets and quotes.
      OPENING = [
        0x3008, 0x300A, 0x300C, 0x300E, 0x3010, 0x3014, 0x3016, 0x3018, 0x301A, 0x301D,
        0xFE59, 0xFE5B, 0xFE5D,
        0xFF08, 0xFF3B, 0xFF5B, 0xFF5F, 0xFF62
      ].freeze

      CLOSING_CODES = CLOSING.flat_map { |entry| Array(entry) }.to_h { |code| [code, true] }.freeze
      OPENING_CODES = OPENING.flat_map { |entry| Array(entry) }.to_h { |code| [code, true] }.freeze

      module_function

      def ideographic?(char)
        code = char.ord
        !CLOSING_CODES.key?(code) && IDEOGRAPHIC.any? { |range| range.cover?(code) }
      end

      def closing?(char) = CLOSING_CODES.key?(char.ord)
      def opening?(char) = OPENING_CODES.key?(char.ord)

      # Whether `text` holds any character these rules know about, the cheap
      # test that keeps Latin text on the fast path.
      def cjk?(text) = text.match?(CJK)

      CJK = /[ᄀ-ᇿ⺀-⿟、-ヿ㄀-鿿ꀀ-꓏ꥠ-꥿가-힯豈-﫿︰-﹞！-ﾟ\u{1B000}-\u{1B16F}\u{20000}-\u{3134F}‥…]/

      # The word's break units in order, each `[text, glued]`: `glued` is true
      # for a unit that must stay with the unit before it (it starts with a
      # closing mark), so the caller joins it to whatever came before, even
      # across styled runs. A word without CJK characters is one unit.
      def units(word)
        return [[word, false]] unless cjk?(word)

        units = []
        current = +""
        glued = false
        open = false # current holds opening brackets only, waiting for what they open
        word.each_char do |char|
          if closing?(char)
            glued = true if current.empty?
          elsif starts_unit?(char, current, open)
            units << [current.freeze, glued] unless current.empty?
            current = +""
            glued = false
          end
          current << char
          open = opening?(char) && (open || current.length == 1)
        end
        units << [current.freeze, glued] unless current.empty?
        units
      end

      # Whether `char` opens a new unit after `current`: an opening bracket or
      # an ideographic character does unless `current` is only opening
      # brackets; Latin text does after a unit that ends in a CJK character
      # (an opening bracket or Latin followed by a closing mark stay glued).
      def starts_unit?(char, current, open)
        return false if current.empty? || open
        return true if opening?(char) || ideographic?(char)

        cjk?(current[-1]) && !(closing?(current[-1]) && !ideographic_unit?(current))
      end

      # A unit that carries an ideographic character (as opposed to Latin text
      # followed by a closing mark, such as "abc。").
      def ideographic_unit?(text) = text.each_char.any? { |char| ideographic?(char) }
    end
  end
end
