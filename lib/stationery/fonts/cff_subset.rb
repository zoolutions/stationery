# frozen_string_literal: true

module Stationery
  module Fonts
    # Rewrites a CFF font so every glyph a document did not draw is a bare
    # `endchar`. Glyph ids, the charset, FDSelect, the Private DICTs and all
    # Subrs are kept byte for byte, so CIDs and hinting are unchanged; only the
    # CharStrings INDEX shrinks. Offsets in the Top DICT and the Font DICTs are
    # written as fixed five-byte integers so their size does not depend on the
    # layout they describe. Charstrings are not interpreted: a deprecated
    # `seac` accent in a drawn glyph would lose its base and accent glyphs.
    module CffSubset
      ENDCHAR = "\x0E".b

      module_function

      # Header, Name INDEX, Top DICT INDEX, String and Global Subr INDEXes,
      # then the blocks the Top DICT points at.
      def build(cff, gids)
        blocks = blocks(cff, gids)
        head = cff.data.byteslice(0, cff.name_index.stop)
        globals = cff.data.byteslice(cff.string_index.start, cff.global_subrs.stop - cff.string_index.start)
        pos = head.bytesize + index([top_dict(cff, blocks.transform_values { 0 })]).bytesize + globals.bytesize
        offsets = blocks.transform_values { |block| pos.tap { pos += block.bytesize } }
        blocks[:fd_array] = fd_array(cff, offsets) if cff.cid_keyed?

        [head, index([top_dict(cff, offsets)]), globals, *blocks.values].join
      end

      # The FDArray is sized here with placeholder offsets; build fills them in.
      def blocks(cff, gids)
        keep = Set.new(gids) << 0
        charstrings = Array.new(cff.num_glyphs) { |gid| keep.include?(gid) ? cff.item(cff.charstrings, gid) : ENDCHAR }
        blocks = tables(cff).merge(charstrings: index(charstrings))
        privates(cff).each_with_index { |region, i| blocks[[:private, i]] = region }
        blocks[:fd_array] = fd_array(cff, Hash.new(0)) if cff.cid_keyed?
        blocks
      end

      # Charset, custom Encoding and FDSelect, copied as they are.
      def tables(cff)
        data = cff.data
        top = cff.top
        blocks = {}
        if (offset = top.fetch(CFF::CHARSET, [0]).first) > 2
          blocks[:charset] = data.byteslice(offset, charset_size(data, offset, cff.num_glyphs))
        end
        if (offset = top.fetch(CFF::ENCODING, [0]).first) > 1
          blocks[:encoding] = data.byteslice(offset, encoding_size(data, offset))
        end
        if (offset = top[CFF::FD_SELECT]&.first)
          blocks[:fd_select] = data.byteslice(offset, fd_select_size(data, offset, cff.num_glyphs))
        end
        blocks
      end

      # Each Private DICT with its local Subrs, as one region so the Subrs
      # offset (relative to the Private DICT) still holds.
      def privates(cff)
        font_dicts(cff).map do |dict|
          size, offset = dict.fetch(CFF::PRIVATE)
          stop = offset + size
          if (subrs = CFF.parse_dict(cff.data.byteslice(offset, size))[CFF::SUBRS])
            stop = [stop, cff.index_at(offset + subrs.first).stop].max
          end
          cff.data.byteslice(offset, stop - offset)
        end
      end

      def font_dicts(cff)
        return [cff.top] unless cff.cid_keyed?

        fd_array = cff.index_at(cff.top.fetch(CFF::FD_ARRAY).first)
        fd_array.items.each_index.map { |i| CFF.parse_dict(cff.item(fd_array, i)) }
      end

      def top_dict(cff, offsets)
        encode(CFF.dict_entries(cff.item(cff.top_index, 0))) do |op, operands|
          case op
          when CFF::CHARSET then offsets.key?(:charset) ? [offsets[:charset]] : operands
          when CFF::ENCODING then offsets.key?(:encoding) ? [offsets[:encoding]] : operands
          when CFF::CHARSTRINGS then [offsets[:charstrings]]
          when CFF::FD_SELECT then [offsets[:fd_select]]
          when CFF::FD_ARRAY then [offsets[:fd_array]]
          when CFF::PRIVATE then [operands.first, offsets[[:private, 0]]]
          end
        end
      end

      def fd_array(cff, offsets)
        fd_array = cff.index_at(cff.top.fetch(CFF::FD_ARRAY).first)
        dicts = fd_array.items.each_index.map do |i|
          encode(CFF.dict_entries(cff.item(fd_array, i))) do |op, operands|
            [operands.first, offsets[[:private, i]]] if op == CFF::PRIVATE
          end
        end
        index(dicts)
      end

      # Entries the block answers are rewritten with five-byte integers; the
      # rest keep their original bytes.
      def encode(entries)
        entries.map do |op, operands, raw|
          values = yield(op, operands)
          next raw unless values

          values.map { |value| [29, value].pack("Cl>") }.join + (op >= 1200 ? [12, op - 1200].pack("CC") : op.chr)
        end.join.b
      end

      def index(items)
        offsets = items.each_with_object([1]) { |item, acc| acc << (acc.last + item.bytesize) }
        size = [1, 2, 3, 4].find { |bytes| offsets.last < 256**bytes }
        [items.size, size].pack("nC") + offsets.map { |offset| [offset].pack("N").byteslice(4 - size, size) }.join +
          items.join
      end

      def charset_size(data, offset, num_glyphs)
        format = data.getbyte(offset)
        return 1 + ((num_glyphs - 1) * 2) if format.zero?

        range = format == 1 ? 3 : 4
        pos = offset + 1
        covered = 1
        while covered < num_glyphs
          covered += 1 + (format == 1 ? data.getbyte(pos + 2) : data.byteslice(pos + 2, 2).unpack1("n"))
          pos += range
        end
        pos - offset
      end

      def encoding_size(data, offset)
        format = data.getbyte(offset)
        count = data.getbyte(offset + 1)
        size = 2 + (format.nobits?(0x7F) ? count : count * 2)
        size += 1 + (data.getbyte(offset + size) * 3) if format.allbits?(0x80)
        size
      end

      def fd_select_size(data, offset, num_glyphs)
        data.getbyte(offset).zero? ? 1 + num_glyphs : 5 + (data.byteslice(offset + 1, 2).unpack1("n") * 3)
      end
    end
  end
end
