# frozen_string_literal: true

module Stationery
  module Fonts
    # Reads the Compact Font Format table of an OpenType font (.otf): the
    # INDEX structures, the Top DICT and, for a CID-keyed font, the charset
    # that maps glyph ids to CIDs. Charstrings are not interpreted.
    class CFF
      STANDARD_STRINGS = 391
      CHARSET = 15
      ENCODING = 16
      CHARSTRINGS = 17
      PRIVATE = 18
      ROS = 1230
      FD_ARRAY = 1236
      FD_SELECT = 1237
      SUBRS = 19
      REAL_NIBBLES = [*"0".."9", ".", "E", "E-", nil, "-"].freeze

      # An INDEX from `start` to `stop` (exclusive); items are [offset, length].
      Index = Data.define(:start, :items, :stop)

      attr_reader :data, :top, :num_glyphs, :name_index, :top_index, :string_index, :global_subrs, :charstrings

      def initialize(data)
        @data = data.b
        @name_index = index_at(@data.getbyte(2))
        @top_index = index_at(@name_index.stop)
        @string_index = index_at(@top_index.stop)
        @global_subrs = index_at(@string_index.stop)
        @top = self.class.parse_dict(item(@top_index, 0))
        @charstrings = index_at(@top.fetch(CHARSTRINGS).first)
        @num_glyphs = @charstrings.items.size
        @charset = self.class.parse_charset(@data, @top.fetch(CHARSET).first, @num_glyphs) if cid_keyed?
      end

      def inspect = "#<#{self.class} glyphs=#{@num_glyphs}#{" cid" if cid_keyed?}>"

      def cid_keyed? = @top.key?(ROS)

      # [registry, ordering, supplement] of a CID-keyed font.
      def ros
        return unless cid_keyed?

        registry, ordering, supplement = @top[ROS]
        [string(registry), string(ordering), supplement]
      end

      # A name-keyed font has no CIDs; PDF addresses its glyphs by glyph id.
      def cid_for(gid)
        cid_keyed? ? @charset.fetch(gid, 0) : gid
      end

      # The contours of a glyph (an Outline), from its charstring.
      def outline(gid)
        return Outline.new unless gid.between?(0, @num_glyphs - 1)

        offset, length = @charstrings.items[gid]
        Charstring.new(@data, @global_subrs, local_subrs(gid)).outline(offset, length)
      end

      # The local Subrs INDEX a glyph's charstring calls, or nil: the Private
      # DICT's, or in a CID-keyed font that of the Font DICT FDSelect gives
      # the glyph. Read once per Font DICT.
      def local_subrs(gid)
        fd = cid_keyed? ? fd_index(gid) : 0
        (@local_subrs ||= {}).fetch(fd) { @local_subrs[fd] = private_subrs(font_dict(fd)) }
      end

      def item(index, number) = @data.byteslice(*index.items.fetch(number))

      def string(sid) = item(@string_index, sid - STANDARD_STRINGS)

      class << self
        # { operator => operands }; two-byte operators are 1200 + the second byte.
        def parse_dict(bytes) = dict_entries(bytes).to_h { |op, operands, _| [op, operands] }

        # [operator, operands, raw bytes of operands and operator] in order.
        def dict_entries(bytes)
          entries = []
          operands = []
          start = pos = 0
          while pos < bytes.bytesize
            b0 = bytes.getbyte(pos)
            if b0 <= 21
              op = b0 == 12 ? 1200 + bytes.getbyte(pos + 1) : b0
              pos += b0 == 12 ? 2 : 1
              entries << [op, operands, bytes.byteslice(start, pos - start)]
              operands = []
              start = pos
            else
              value, pos = operand(bytes, pos)
              operands << value
            end
          end
          entries
        end

        # The SID (name-keyed) or CID (CID-keyed) of every glyph, by glyph id.
        def parse_charset(data, offset, num_glyphs)
          format = data.getbyte(offset)
          return [0, *data.byteslice(offset + 1, (num_glyphs - 1) * 2).unpack("n*")] if format.zero?

          ids = [0]
          pos = offset + 1
          while ids.size < num_glyphs
            first, left = data.byteslice(pos, format == 1 ? 3 : 4).unpack(format == 1 ? "nC" : "nn")
            ids.concat((first..(first + left)).to_a)
            pos += format == 1 ? 3 : 4
          end
          ids.first(num_glyphs)
        end

        private

        def operand(bytes, pos)
          b0 = bytes.getbyte(pos)
          case b0
          when 28 then [bytes.byteslice(pos + 1, 2).unpack1("s>"), pos + 3]
          when 29 then [bytes.byteslice(pos + 1, 4).unpack1("l>"), pos + 5]
          when 30 then real(bytes, pos + 1)
          when 32..246 then [b0 - 139, pos + 1]
          when 247..250 then [((b0 - 247) * 256) + bytes.getbyte(pos + 1) + 108, pos + 2]
          when 251..254 then [((251 - b0) * 256) - bytes.getbyte(pos + 1) - 108, pos + 2]
          else raise UnsupportedFont, "malformed CFF DICT operand #{b0}"
          end
        end

        def real(bytes, pos)
          text = +""
          loop do
            byte = bytes.getbyte(pos)
            pos += 1
            [byte >> 4, byte & 0x0F].each do |nibble|
              return [Float(text), pos] if nibble == 0x0F

              text << REAL_NIBBLES.fetch(nibble)
            end
          end
        end
      end

      def index_at(offset)
        count = @data.byteslice(offset, 2).unpack1("n")
        return Index.new(offset, [], offset + 2) if count.zero?

        size = @data.getbyte(offset + 2)
        offsets = Array.new(count + 1) do |i|
          @data.byteslice(offset + 3 + (i * size), size).bytes.inject(0) { |value, byte| (value << 8) | byte }
        end
        base = offset + 2 + ((count + 1) * size)
        Index.new(offset, offsets.each_cons(2).map { |a, b| [base + a, b - a] }, base + offsets.last)
      end

      private

      def font_dict(number)
        return @top unless cid_keyed?

        @fd_array ||= index_at(@top.fetch(FD_ARRAY).first)
        self.class.parse_dict(item(@fd_array, number))
      end

      # The Subrs offset is relative to the Private DICT.
      def private_subrs(dict)
        size, offset = dict.fetch(PRIVATE)
        subrs = self.class.parse_dict(@data.byteslice(offset, size))[SUBRS]
        index_at(offset + subrs.first) if subrs
      end

      # FDSelect format 0 has a Font DICT per glyph; format 3 sorted ranges
      # of [first glyph, Font DICT] ending at a sentinel glyph id, searched
      # for the first range whose successor starts past the glyph.
      def fd_index(gid)
        offset = @top.fetch(FD_SELECT).first
        return @data.getbyte(offset + 1 + gid) if @data.getbyte(offset).zero?

        ranges = offset + 3
        range = (0...@data.unpack1("n", offset: offset + 1)).bsearch do |i|
          @data.unpack1("n", offset: ranges + (3 * (i + 1))) > gid
        end
        range ? @data.getbyte(ranges + (3 * range) + 2) : 0
      end
    end
  end
end
