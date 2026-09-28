# frozen_string_literal: true

module Stationery
  module Barcode
    # Code 128 (ISO/IEC 15417) of printable ASCII (" " to "~"): code set B,
    # switching to code set C (two digits a symbol) for a run of at least six
    # digits, or four at either end. Bars and spaces are 1 to 4 modules wide;
    # the symbol is 11 modules a character, 13 for the stop, with a quiet
    # zone of 10 modules on either side.
    class Code128
      PATTERNS = %w[
        212222 222122 222221 121223 121322 131222 122213 122312 132212 221213 221312 231212 112232 122132 122231
        113222 123122 123221 223211 221132 221231 213212 223112 312131 311222 321122 321221 312212 322112 322211
        212123 212321 232121 111323 131123 131321 112313 132113 132311 211313 231113 231311 112133 112331 132131
        113123 113321 133121 313121 211331 231131 213113 213311 213131 311123 311321 331121 312113 312311 332111
        314111 221411 431111 111224 111422 121124 121421 141122 141221 112214 112412 122114 122411 142112 142211
        241211 221114 413111 241112 134111 111242 121142 121241 114212 124112 124211 411212 421112 421211 212141
        214121 412121 111143 111341 131141 114113 114311 411113 411311 113141 114131 311141 411131 211412 211214
        211232 2331112
      ].freeze
      START_B = 104
      START_C = 105
      CODE_B = 100
      CODE_C = 99
      STOP = 106
      QUIET = 10
      # How ZPL's ^BC (mode N) is told to start or change code set.
      ZPL_SET = { START_B => ">:", START_C => ">;", CODE_B => ">6", CODE_C => ">5" }.freeze

      attr_reader :data, :codes

      def initialize(data)
        @data = data.to_s
        raise ArgumentError, "a Code 128 barcode needs data" if @data.empty?

        bad = @data.each_char.find { |char| !char.ord.between?(32, 126) }
        raise ArgumentError, "Code 128 takes printable ASCII (\" \" to \"~\"), not #{bad.inspect}" if bad

        @parts = parts
        @codes = checked(@parts.flat_map { |set, text| [set, *values(set, text)] })
      end

      def linear? = true
      def native? = true
      # Dots ZPL draws the symbol below its ^FO.
      def zpl_top = 0
      def quiet = QUIET

      # Modules across, without the quiet zones.
      def width = ((@codes.size - 1) * 11) + 13

      # The bars, as [first module, modules wide].
      def bars
        x = 0
        @codes.flat_map { |code| PATTERNS[code].chars.map(&:to_i) }.each_slice(2).filter_map do |bar, space|
          [x, bar].tap { x += bar + space.to_i }
        end
      end

      # The ^BC command drawing the same symbol: its code sets named, so the
      # printer does not choose others.
      def zpl(module_dots:, height_dots:)
        text = @parts.map { |set, part| ZPL_SET.fetch(set) + part.gsub(">", "><") }.join
        "^BY#{module_dots}^BCN,#{height_dots},N,N,N,N#{Barcode.field(text)}"
      end

      private

      # The data as [set, text] runs, the first set being a start code.
      def parts
        runs = @data.scan(/\d+|\D+/)
        pieces = runs.each_with_index.flat_map do |run, index|
          edge = index.zero? || index == runs.size - 1
          next [[CODE_B, run]] unless run.match?(/\A\d+\z/) && run.size >= (edge ? 4 : 6)

          even = run.size.even? ? run : run[...-1]
          [[CODE_C, even], *([[CODE_B, run[-1]]] if even.size < run.size)]
        end
        list = pieces.chunk_while { |a, b| a[0] == b[0] }.map { |group| [group[0][0], group.map(&:last).join] }
        list[0][0] = list[0][0] == CODE_C ? START_C : START_B
        list
      end

      def values(set, text)
        return text.scan(/\d\d/).map(&:to_i) if [START_C, CODE_C].include?(set)

        text.each_char.map { |char| char.ord - 32 }
      end

      def checked(codes)
        sum = codes.each_with_index.sum { |code, index| code * [index, 1].max }
        [*codes, sum % 103, STOP]
      end
    end
  end
end
