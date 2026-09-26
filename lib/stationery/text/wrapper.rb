# frozen_string_literal: true

module Stationery
  module Text
    # Greedy line breaking over styled runs. Breaks at spaces (the space is
    # dropped at the break) and after hyphens; a word wider than the line is
    # broken between characters. A word that changes style midway ("<b>Tot</b>al")
    # is still one word.
    class Wrapper
      TOKEN = /\n|[ \t]+|[^ \t\n-]*-+|[^ \t\n-]+/

      Segment = Data.define(:text, :style)

      def initialize(book)
        @book = book
      end

      def wrap(runs, max_width, fallback_style: runs.first&.style)
        @max = max_width
        @lines = []
        @current = []
        @pending_space = []
        @fallback = fallback_style
        items(runs).each { |item| place(item) }
        finish unless @current.empty? && @lines.any? && !@ended_with_newline
        @lines
      end

      private

      # [:word, segments] | [:space, segments] | [:newline]
      def items(runs)
        items = []
        runs.each do |run|
          run.text.scan(TOKEN) do |token|
            if token == "\n" then items << [:newline]
            elsif token.match?(/\A[ \t]/) then items << [:space, [Segment.new(token, run.style)]]
            elsif items.last&.first == :word && !items.last.last.last.text.end_with?("-")
              items.last.last << Segment.new(token, run.style)
            else items << [:word, [Segment.new(token, run.style)]]
            end
          end
        end
        items
      end

      def place((kind, segments))
        @ended_with_newline = kind == :newline
        case kind
        when :newline then finish
        when :space then @pending_space += segments
        else place_word(segments)
        end
      end

      def place_word(word)
        needed = width(@pending_space) + width(word)
        if @current.empty? || line_width + needed <= @max + 0.0001
          @current.concat(@pending_space, word)
        else
          finish(wrapped: true)
          @current.concat(word)
        end
        @pending_space = []
        break_long_word while line_width > @max + 0.0001 && characters(@current) > 1
      end

      # Moves characters that overflow the line onto following lines.
      def break_long_word
        fitting = []
        @current.each do |segment|
          segment.text.each_char do |char|
            piece = Segment.new(char, segment.style)
            return keep_overflow(fitting, piece) if fitting.any? && width(fitting + [piece]) > @max + 0.0001

            fitting << piece
          end
        end
      end

      def keep_overflow(fitting, piece)
        rest = remaining_after(fitting.size)
        @current = fitting
        finish(wrapped: true)
        @current = [piece, *rest.drop(1)]
      end

      def remaining_after(count)
        @current.flat_map { |segment| segment.text.chars.map { |char| Segment.new(char, segment.style) } }.drop(count)
      end

      def finish(wrapped: false)
        segments = wrapped ? @current : @current + @pending_space
        @lines << Line.new(fragments(trim_trailing(segments)), fallback_metrics)
        @current = []
        @pending_space = []
      end

      def trim_trailing(segments)
        segments = segments.dup
        segments.pop while segments.last && segments.last.text.strip.empty?
        segments
      end

      def fragments(segments)
        x = 0
        segments.chunk_while { |a, b| a.style == b.style }.map do |group|
          text = group.map(&:text).join
          font, face = @book.resolve(group.first.style)
          fragment_width = measure(text, group.first.style)
          Fragment.new(text, group.first.style, font, face, fragment_width, x).tap { x += fragment_width }
        end
      end

      def fallback_metrics
        [@book.resolve(@fallback).first, @fallback.render_size]
      end

      def line_width = width(@current)
      def characters(segments) = segments.sum { |segment| segment.text.length }

      def width(segments)
        segments.sum { |segment| measure(segment.text, segment.style) }
      end

      def measure(text, style)
        @book.resolve(style).first.width_of(text, style.render_size, letter_spacing: style.letter_spacing)
      end
    end
  end
end
