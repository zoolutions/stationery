# frozen_string_literal: true

module Stationery
  module Fonts
    # Glyph substitution from the font's GSUB table: every feature's
    # SingleSubst (type 1) and LigatureSubst (type 4) lookups, directly or
    # behind Extension lookups. `liga` gives the standard ligatures; `smcp`,
    # `onum`, `tnum`, `dlig`, `ss01` and the rest are applied on request.
    # Contextual lookups (types 5, 6 and 8) are not read, so `calt` and
    # `clig` do nothing. Scripts, languages and lookup flags are not
    # distinguished.
    class Gsub
      SINGLE = 1
      LIGATURE = 4
      EXTENSION = 7
      LIGA = ["liga"].freeze

      # nil when the font has no GSUB table, an unknown version, or no lookup
      # of a supported type behind any feature.
      def self.parse(ttf)
        base = ttf.table_offset("GSUB")
        return unless base && ttf.u16(base) == 1

        lookups = {}
        features = feature_indices(ttf, base + ttf.u16(base + 6)).transform_values do |indices|
          indices.filter_map do |i|
            subtables = lookups[i] ||= lookup(ttf, base + ttf.u16(base + 8), i)
            [i, subtables] unless subtables.empty?
          end.freeze
        end
        features.reject! { |_, lookups_for| lookups_for.empty? }
        new(features) if features.any?
      end

      # { tag => [lookup index, ...] } from the FeatureList, every record of a
      # tag merged, in LookupList order.
      def self.feature_indices(ttf, list)
        Array.new(ttf.u16(list)) { |i| list + 2 + (i * 6) }.each_with_object({}) do |record, features|
          tag = ttf.data.byteslice(record, 4)
          feature = list + ttf.u16(record + 4)
          indices = Array.new(ttf.u16(feature + 2)) { |j| ttf.u16(feature + 4 + (j * 2)) }
          features[tag] = ((features[tag] || []) | indices).sort
        end
      end
      private_class_method :feature_indices

      # The `index`th lookup's supported subtables; other types have none.
      def self.lookup(ttf, list, index)
        offset = list + ttf.u16(list + 2 + (index * 2))
        type = ttf.u16(offset)
        subtables = Array.new(ttf.u16(offset + 4)) { |i| offset + ttf.u16(offset + 6 + (i * 2)) }
        subtables.filter_map do |subtable|
          if type == EXTENSION
            read(ttf.u16(subtable + 2), ttf, subtable + ttf.u32(subtable + 4))
          else
            read(type, ttf, subtable)
          end
        end.freeze
      end
      private_class_method :lookup

      def self.read(type, ttf, offset)
        case type
        when SINGLE then SingleSubst.read(ttf, offset)
        when LIGATURE then LigatureSubst.read(ttf, offset)
        end
      end
      private_class_method :read

      def initialize(features)
        @features = features.freeze
        @plans = {}
        freeze
      end

      # The feature tags this font can apply, e.g. ["liga", "onum", "tnum"].
      def features = @features.keys

      # [[gid, number of source glyphs it stands for], ...] after applying the
      # lookups of `tags` (feature tag Strings) in LookupList order, each once.
      # Within a lookup the first subtable matching at a position wins and its
      # glyph is not matched again by that lookup.
      def substitute(gids, tags = LIGA)
        plan(tags).reduce(gids.map { |gid| [gid, 1] }) { |glyphs, subtables| apply(subtables, glyphs) }
      end

      private

      # The lookups the tags name, merged and ordered; remembered per tag list.
      def plan(tags)
        @plans[tags] ||= tags.flat_map { |tag| @features[tag] || [] }.uniq(&:first).sort_by(&:first)
                             .map(&:last).freeze
      end

      def apply(subtables, glyphs)
        ids = glyphs.map(&:first)
        result = []
        i = 0
        while i < glyphs.size
          match = nil
          subtables.find { |subtable| match = subtable.match(ids, i) }
          length = match ? match.last : 1
          result << [match ? match.first : ids[i], glyphs[i, length].sum(&:last)]
          i += length
        end
        result
      end
    end
  end
end
