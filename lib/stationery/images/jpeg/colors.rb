# frozen_string_literal: true

module Stationery
  module Images
    class JPEG
      # A decoded frame's components as 8-bit grey or RGB samples, row after
      # row: chroma upsampled (Upsampler), then YCbCr turned into RGB with the
      # JFIF formulas in libjpeg's fixed point (jdcolor.c). Three components
      # are YCbCr unless an Adobe segment says RGB (transform 0) or, without
      # one, the component ids spell R, G, B. Four are CMYK, YCCK under Adobe
      # transform 2, stored inverted when an Adobe segment is there (as
      # Photoshop writes them, and as the PDF's Decode array reads them), and
      # are turned into RGB as (1 - C) × (1 - K) and so on.
      module Colors
        # 1.402 × (Cr - 128), 1.772 × (Cb - 128), and the green part of both
        # scaled by 2^16, as libjpeg tabulates them.
        RED = Array.new(256) { |i| ((91_881 * (i - 128)) + 32_768) >> 16 }.freeze
        BLUE = Array.new(256) { |i| ((116_130 * (i - 128)) + 32_768) >> 16 }.freeze
        GREEN = Array.new(65_536) do |i|
          ((-22_554 * ((i >> 8) - 128)) + (-46_802 * ((i & 255) - 128)) + 32_768) >> 16
        end.freeze
        CLAMP = Array.new(1024) { |i| (i - 384).clamp(0, 255) }.freeze
        OFFSET = 384
        RGB_IDS = [82, 71, 66].freeze

        module_function

        # [samples, channels] of `decoder` at its scale.
        def call(decoder)
          scale = decoder.scale
          width = (decoder.width + scale - 1) / scale
          height = (decoder.height + scale - 1) / scale
          rows = upsamplers(decoder, width, scale)
          return [grey(rows.first, width, height), 1] if rows.size == 1

          [color(rows, width, height, transform(decoder), !decoder.adobe.nil?), 3]
        end

        def upsamplers(decoder, width, scale)
          max_h = decoder.max_h
          max_v = decoder.max_v
          least = 8 / scale
          decoder.components.map do |c|
            in_width = ((decoder.width * c.h * c.block) + (max_h * 8) - 1) / (max_h * 8)
            in_height = ((decoder.height * c.v * c.block) + (max_v * 8) - 1) / (max_v * 8)
            factors = [(max_h * least) / (c.h * c.block), (max_v * least) / (c.v * c.block)]
            Upsampler.new(c, in_width, in_height, width, factors, fancy: scale < 8)
          end
        end

        def transform(decoder)
          if decoder.components.size == 3
            return :rgb if decoder.adobe&.zero?
            return :rgb if decoder.adobe.nil? && decoder.components.map(&:id) == RGB_IDS

            :ycc
          else
            decoder.adobe == 2 ? :ycck : :cmyk
          end
        end

        def grey(rows, width, height)
          out = String.new(capacity: width * height, encoding: Encoding::BINARY)
          height.times { |y| out << rows.row(y).pack("C*") }
          out
        end

        def color(upsamplers, width, height, transform, inverted)
          out = "\0".b * (width * height * 3)
          height.times do |y|
            rows = upsamplers.map { |upsampler| upsampler.row(y) }
            at = y * width * 3
            case transform
            when :ycc then ycc(out, at, *rows, width)
            when :rgb then rgb(out, at, *rows, width)
            else cmyk(out, at, rows, transform == :ycck, inverted)
            end
          end
          out
        end

        def ycc(out, at, luma, blue, red, width)
          x = 0
          while x < width
            l = luma[x] + OFFSET
            b = blue[x]
            r = red[x]
            out.setbyte(at, CLAMP[l + RED[r]])
            out.setbyte(at + 1, CLAMP[l + GREEN[(b << 8) | r]])
            out.setbyte(at + 2, CLAMP[l + BLUE[b]])
            at += 3
            x += 1
          end
        end

        def rgb(out, at, red, green, blue, width)
          width.times do |x|
            out.setbyte(at, red[x])
            out.setbyte(at + 1, green[x])
            out.setbyte(at + 2, blue[x])
            at += 3
          end
        end

        # CMYK (or YCCK, whose YCC is CMY as if it were RGB) into RGB, as
        # Pillow does: red is (255 - K) less C of it. Inverted samples are
        # 255 for no ink.
        def cmyk(out, at, rows, ycck, inverted)
          first, second, third, black = rows
          flip = inverted ? 255 : 0
          first.each_index do |x|
            inks = ycck ? ycck_cmy(first[x], second[x], third[x]) : [first[x], second[x], third[x]]
            paper = 255 - (black[x] ^ flip)
            inks.each_with_index { |ink, i| out.setbyte(at + i, paper - multiply(ink ^ flip, paper)) }
            at += 3
          end
        end

        # libjpeg's ycck_cmyk_convert: the CMY of a YCCK pixel, inverted.
        def ycck_cmy(luma, blue, red)
          l = luma + OFFSET
          [255 - CLAMP[l + RED[red]], 255 - CLAMP[l + GREEN[(blue << 8) | red]], 255 - CLAMP[l + BLUE[blue]]]
        end

        # a × b / 255, rounded as Pillow rounds it.
        def multiply(a, b)
          product = (a * b) + 128
          ((product >> 8) + product) >> 8
        end
      end
    end
  end
end
