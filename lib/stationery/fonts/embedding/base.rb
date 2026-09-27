# frozen_string_literal: true

require "digest/md5"

module Stationery
  module Fonts
    module Embedding
      # What every CIDFont embedding shares: the font descriptor's metrics, the
      # glyph widths keyed by character code, and the subset tag.
      class Base
        IDENTITY = { Registry: "Adobe", Ordering: "Identity", Supplement: 0 }.freeze

        def initialize(font)
          @font = font
          @ttf = font.ttf
        end

        private

        def descriptor(writer, name, **font_file)
          writer.add(
            Type: :FontDescriptor, FontName: name, Flags: flags,
            FontBBox: @ttf.bbox.map { |v| glyph_space(v) }, ItalicAngle: @ttf.italic_angle,
            Ascent: glyph_space(@ttf.ascender), Descent: glyph_space(@ttf.descender),
            CapHeight: glyph_space(@ttf.cap_height), XHeight: glyph_space(@ttf.x_height),
            StemV: @font.bold? ? 120 : 80, **font_file
          )
        end

        # The W array: runs of consecutive codes, each with its glyphs' widths.
        def widths(gids)
          pairs = gids.map { |gid| [@font.code(gid), gid] }.sort
          pairs.slice_when { |(a, _), (b, _)| b != a + 1 }.flat_map do |run|
            [run.first.first, run.map { |_, gid| glyph_space(@ttf.advance(gid)) }]
          end
        end

        def glyph_space(units)
          (units * 1000.0 / @ttf.units_per_em).round
        end

        def flags
          flags = 32 # Nonsymbolic
          flags |= 1 if @ttf.fixed_pitch?
          flags |= 64 unless @ttf.italic_angle.zero?
          flags
        end

        # Subset fonts are named with six uppercase letters: ABCDEF+OpenSans-Regular.
        def subset_tag(gids)
          Digest::MD5.digest(gids.pack("n*") + @ttf.postscript_name).bytes.first(6).map { |b| (65 + (b % 26)).chr }.join
        end
      end
    end
  end
end
