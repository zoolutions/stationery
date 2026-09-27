# frozen_string_literal: true

# Builds small GPOS tables byte by byte, for the lookup shapes the fixture
# fonts do not contain (Extension lookups, every Coverage/ClassDef format,
# wide value records). Each builder returns the packed bytes of one table;
# offsets are laid out by concatenating a header with its children.
module GposBuilder
  # Just enough of TrueType's reader interface for Fonts::Gpos.
  class Table
    attr_reader :data

    def initialize(gpos) = @data = gpos.b
    def table_offset(tag) = tag == "GPOS" ? 0 : nil
    def u16(offset) = @data.byteslice(offset, 2).unpack1("n")
    def i16(offset) = @data.byteslice(offset, 2).unpack1("s>")
    def u32(offset) = @data.byteslice(offset, 4).unpack1("N")
  end

  module_function

  def gpos(features:, lookups:, version: 1)
    feature_list = feature_list(features)
    lookup_list = offsets_table(lookups)
    header = [version, 0, 10, 12, 12 + feature_list.bytesize].pack("n*")
    Table.new(header + [0].pack("n") + feature_list + lookup_list)
  end

  # features: [[tag, [lookup indices]]]
  def feature_list(features)
    records_size = 2 + (features.size * 6)
    bodies = features.map { |_tag, indices| [0, indices.size, *indices].pack("n*") }
    offset = records_size
    records = features.each_with_index.map do |(tag, _), i|
      (tag.b + [offset].pack("n")).tap { offset += bodies[i].bytesize }
    end
    [features.size].pack("n") + records.join + bodies.join
  end

  def lookup(type, subtables) = offsets_table(subtables, [type, 0, subtables.size])

  def extension(type, subtable) = [1, type, 8].pack("nnN") + subtable

  # A table of 16-bit offsets to `children`, after `head` (a count by default).
  def offsets_table(children, head = [children.size])
    offset = (head.size + children.size) * 2
    offsets = children.map { |child| offset.tap { offset += child.bytesize } }
    [*head, *offsets].pack("n*") + children.join
  end

  def coverage1(gids) = [1, gids.size, *gids.sort].pack("n*")

  def coverage2(ranges)
    index = 0
    [2, ranges.size].pack("n*") + ranges.map { |r| [r.first, r.last, index].pack("n*").tap { index += r.size } }.join
  end

  def class_def1(start, classes) = [1, start, classes.size, *classes].pack("n*")

  def class_def2(ranges)
    [2, ranges.size, *ranges.flat_map { |range, klass| [range.first, range.last, klass] }].pack("n*")
  end

  # Value records: one signed 16-bit field per bit set in the format.
  def value(format, fields) = fields.first(format.digits(2).count(1)).pack("s>*")

  # pair_sets: { left_gid => { right_gid => [fields1, fields2] } }, coverage
  # listing the left glyphs in order.
  def pair_pos1(coverage, pair_sets, vf1:, vf2:)
    sets = pair_sets.sort.map do |_left, pairs|
      records = pairs.sort.map { |right, (v1, v2)| [right].pack("n") + value(vf1, v1) + value(vf2, v2) }
      [pairs.size].pack("n") + records.join
    end
    head_size = 10 + (sets.size * 2)
    offset = head_size + coverage.bytesize
    offsets = sets.map { |set| offset.tap { offset += set.bytesize } }
    [1, head_size, vf1, vf2, sets.size, *offsets].pack("n*") + coverage + sets.join
  end

  # matrix[class1][class2] = [fields1, fields2]
  def pair_pos2(coverage, class_def1, class_def2, matrix, vf1:, vf2:)
    records = matrix.map { |row| row.map { |v1, v2| value(vf1, v1) + value(vf2, v2) }.join }.join
    head = 16
    at_coverage = head + records.bytesize
    at_def1 = at_coverage + coverage.bytesize
    at_def2 = at_def1 + class_def1.bytesize
    [2, at_coverage, vf1, vf2, at_def1, at_def2, matrix.size, matrix.first.size].pack("n*") +
      records + coverage + class_def1 + class_def2
  end
end
