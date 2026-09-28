# frozen_string_literal: true

# Builds small GSUB tables byte by byte, reusing GposBuilder's layout of the
# shared header, FeatureList, LookupList, Coverage and Extension shapes.
module GsubBuilder
  # Just enough of TrueType's reader interface for Fonts::Gsub.
  class Table < GposBuilder::Table
    def table_offset(tag) = tag == "GSUB" ? 0 : nil
  end

  module_function

  def gsub(features:, lookups:, version: 1)
    Table.new(GposBuilder.gpos(features:, lookups:, version:).data)
  end

  # SingleSubst format 1: every covered glyph plus `delta`.
  def single_subst1(coverage, delta) = [1, 6, delta].pack("nns>") + coverage

  # SingleSubst format 2: the substitute for each covered glyph, in coverage order.
  def single_subst2(coverage, gids) = [2, 6 + (gids.size * 2), gids.size, *gids].pack("n*") + coverage

  # sets: { first_gid => { [component gids after the first] => ligature gid } },
  # coverage listing the first glyphs in order.
  def ligature_subst(coverage, sets)
    tables = sets.sort.map do |_first, ligatures|
      GposBuilder.offsets_table(ligatures.map { |rest, glyph| [glyph, rest.size + 1, *rest].pack("n*") })
    end
    head_size = 6 + (tables.size * 2)
    offset = head_size + coverage.bytesize
    offsets = tables.map { |table| offset.tap { offset += table.bytesize } }
    [1, head_size, tables.size, *offsets].pack("n*") + coverage + tables.join
  end
end
