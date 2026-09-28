# frozen_string_literal: true

module Stationery
  module Fonts
    # One font's side of the shaper hook (see Shaper): asks the document's
    # shaper to place a text, checks the answer and remembers it per size,
    # features and text, so measuring a stretch and then drawing it asks once.
    # Like the font's own memos, what is remembered starts over after
    # Font::MEMO_BYTES of text, so a long document does not keep every line.
    class Shaping
      def initialize(font, shaper, path: nil, language: nil)
        @font = font
        @shaper = shaper
        @language = language
        @path = path
        @features = {}
        @runs = {}
        @memoised = 0
      end

      # The ShapedRun of `text`, or nil when the shaper declines it.
      def run(text, size, kerning:, ligatures:, features:)
        features = switches(kerning ? true : false, ligatures ? true : false, features)
        runs = ((@runs[size] ||= {}.compare_by_identity)[features] ||= {})
        runs.fetch(text) do
          forget if (@memoised += text.bytesize) > Font::MEMO_BYTES
          runs[text] = shape(text, size, features)
        end
      end

      # What the shaper is told about the font.
      def face
        @face ||= begin
          ttf = @font.ttf
          path, index = Registry::FACE.match(@path.to_s)&.captures || [@path, 0]
          Shaper::Face.new(path: path && File.expand_path(path.to_s), index: index.to_i, data: ttf.data,
                           units_per_em: ttf.units_per_em, postscript_name: ttf.postscript_name,
                           glyph_count: ttf.num_glyphs)
        end
      end

      private

      def forget
        @runs.each_value { |sizes| sizes.each_value(&:clear) }
        @memoised = 0
      end

      # { tag => on }, one frozen Hash per set of switches so the runs are
      # remembered by its identity.
      def switches(kerning, ligatures, features)
        tags = Text::Style.features(features)
        @features[[kerning, ligatures, tags]] ||=
          { "kern" => kerning, "liga" => ligatures }.merge(tags.to_h { |tag| [tag, true] }).freeze
      end

      def shape(text, size, features)
        answer = @shaper.call(text, face, size:, features:, language: @language)
        answer && ShapedRun.build(@font, size, text, Shaper.glyphs(answer, text, face))
      end
    end
  end
end
