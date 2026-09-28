# frozen_string_literal: true

require "forwardable"

module Stationery
  module Testing
    # A pdf-reader receiver that collects a page's text by MCID, and the text
    # shown outside any marked content. Text on a new baseline starts after
    # a space, so a paragraph's lines read as one string.
    class MarkedText
      extend Forwardable

      STATE = %i[save_graphics_state restore_graphics_state concatenate_matrix begin_text_object end_text_object
                 set_text_font_and_size move_text_position move_text_position_and_set_leading
                 set_text_matrix_and_text_line_matrix move_to_start_of_next_line set_text_leading
                 set_character_spacing set_word_spacing set_text_rise set_horizontal_text_scaling
                 set_text_rendering_mode].freeze

      UTF16_BOM = "\xFE\xFF".b

      def_delegators :@state, *STATE

      # { MCID => text } and the strings shown outside marked content.
      attr_reader :texts, :unmarked

      def self.read(page) = new(page).tap { |receiver| page.walk(receiver) }

      def initialize(page)
        @state = ::PDF::Reader::PageState.new(page)
        @open = []
        @texts = {}
        @baselines = {}
        @unmarked = []
      end

      # A sequence with ActualText reads as that text, whatever it shows.
      def begin_marked_content_with_pl(_tag, properties)
        properties = {} unless properties.is_a?(Hash)
        @open << properties[:MCID]
        return unless properties[:ActualText]

        @actual = decode(properties[:ActualText])
        @actual_depth = @open.size
      end

      def begin_marked_content(_tag) = @open << nil

      def end_marked_content
        @actual = nil if @actual_depth && @open.size <= @actual_depth
        @open.pop
      end

      def show_text(string) = append(string)
      def show_text_with_positioning(params) = params.grep(String).each { |string| append(string) }

      private

      def append(string)
        text = shown(string)
        return @unmarked << text if @open.empty?

        mcid = @open.compact.last
        return unless mcid

        baseline = @state.trm_transform_point(0, 0).y.round(2)
        separator = @texts.key?(mcid) && @baselines[mcid] != baseline ? " " : ""
        @texts[mcid] = "#{@texts[mcid]}#{separator}#{text}"
        @baselines[mcid] = baseline
      end

      # The characters a string shows: its ActualText once, when it has one.
      def shown(string)
        if @actual
          text = @actual
          @actual = ""
          return text
        end

        font = @state.current_font
        font.unpack(string).map { |code| font.to_utf8(code) }.join
      end

      def decode(text)
        return text.dup.force_encoding(Encoding::UTF_8) unless text.b.start_with?(UTF16_BOM)

        text.b.byteslice(2..).force_encoding(Encoding::UTF_16BE).encode(Encoding::UTF_8)
      end
    end
  end
end
