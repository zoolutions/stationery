# frozen_string_literal: true

module Stationery
  module Testing
    # A pdf-reader receiver that collects a page's text by MCID, the text
    # shown outside any marked content, and the text as the page lays it out.
    # Text on a new baseline starts after a space, so a paragraph's lines read
    # as one string.
    #
    # The layout is pdf-reader's own, glyph by glyph, but for a sequence with
    # ActualText: that is one run of its text, from where its first glyph is
    # shown to where the pen is when it ends. pdf-reader gives the text to the
    # first glyph and drops a glyph without a width, which a mark drawn before
    # its base is.
    class MarkedText
      STATE = %i[save_graphics_state restore_graphics_state concatenate_matrix begin_text_object end_text_object
                 set_text_font_and_size move_text_position move_text_position_and_set_leading
                 set_text_matrix_and_text_line_matrix move_to_start_of_next_line set_text_leading
                 set_character_spacing set_word_spacing set_text_rise set_horizontal_text_scaling
                 set_text_rendering_mode].freeze

      UTF16_BOM = "\xFE\xFF".b
      # The width of a character in a sequence that moves the pen nowhere, in
      # parts of its size.
      NOMINAL = 0.5

      # A sequence with ActualText: its text, where the pen was when its
      # first glyph was shown, at what size, and where the pen was when it
      # ended: back on the baseline, after a mark that was lifted off it.
      Sequence = Struct.new(:text, :from, :font_size, :to)

      # The state is kept twice: the pen of `@state` stays where a line
      # starts, which is what tells one baseline from the next in text that
      # is turned, and the pen of the glyphs moves with what is shown.
      STATE.each do |operator|
        define_method(operator) do |*operands|
          @state.public_send(operator, *operands)
          @glyphs.state.public_send(operator, *operands)
        end
      end

      # { MCID => text } and the strings shown outside marked content.
      attr_reader :texts, :unmarked

      def self.read(page) = new(page).tap { |receiver| page.walk(receiver) }

      def initialize(page)
        @page = page
        @state = ::PDF::Reader::PageState.new(page)
        @glyphs = ::PDF::Reader::PageTextReceiver.new.tap { |receiver| receiver.page = page }
        @open = []
        @texts = {}
        @baselines = {}
        @unmarked = []
        @sequences = []
      end

      # The text of the page as pdf-reader lays it out.
      def layout
        runs = @glyphs.runs(merge: false) + @sequences.map { |sequence| run(sequence) }
        ::PDF::Reader::PageLayout.new(merge(runs), @page.rectangles[:MediaBox]).to_s
      end

      # A sequence with ActualText reads as that text, whatever it shows.
      def begin_marked_content_with_pl(_tag, properties)
        properties = {} unless properties.is_a?(Hash)
        @open << properties[:MCID]
        return unless properties[:ActualText]

        @actual = decode(properties[:ActualText])
        @actual_depth = @open.size
        @sequence = Sequence.new(@actual)
      end

      def begin_marked_content(_tag) = @open << nil

      def end_marked_content
        close if @actual_depth && @open.size <= @actual_depth
        @open.pop
      end

      def show_text(string) = show([string])

      def show_text_with_positioning(params) = show(params)

      def move_to_next_line_and_show_text(string)
        move_to_start_of_next_line
        show_text(string)
      end

      def set_spacing_next_line_show_text(word_spacing, character_spacing, string)
        set_word_spacing(word_spacing)
        set_character_spacing(character_spacing)
        move_to_next_line_and_show_text(string)
      end

      # A form drawn on the page is read as part of it.
      def invoke_xobject(label)
        @state.invoke_xobject(label) do |form|
          @glyphs.state.invoke_xobject(label) { form.walk(self) if form.is_a?(::PDF::Reader::FormXObject) }
        end
      end

      private

      def show(params)
        params.grep(String).each { |string| append(string) }
        return @glyphs.show_text_with_positioning(params) unless @sequence

        @sequence.from ||= pen
        @sequence.font_size ||= @glyphs.state.font_size
        params.each { |param| param.is_a?(String) ? advance(param) : move(param) }
      end

      def close
        @sequences << @sequence.tap { |sequence| sequence.to = pen } if @sequence&.from
        @actual = @sequence = nil
      end

      def append(string)
        text = shown(string)
        return @unmarked << text if @open.empty?

        mcid = @open.compact.last
        return unless mcid

        baseline = @state.trm_transform(0, 0).last.round(2)
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

      # Moves the pen past the glyphs of a string, as showing them does.
      def advance(string)
        font = @glyphs.state.current_font
        font.unpack(string).each do |code|
          @glyphs.state.process_glyph_displacement(font.glyph_width_in_text_space(code), 0, font.to_utf8(code) == " ")
        end
      end

      def move(thousandths) = @glyphs.state.process_glyph_displacement(0, thousandths, false)

      # Where the pen is on the page, turned as pdf-reader turns the glyphs
      # of a rotated page.
      def pen
        x, y = @glyphs.state.trm_transform(0, 0)
        case @page.rotate
        when 90 then [y, -x]
        when 180 then [-x, -y]
        when 270 then [-y, x]
        else [x, y]
        end
      end

      def run(sequence)
        x, = sequence.from
        width = sequence.to[0] - x
        width = sequence.font_size * NOMINAL * sequence.text.length unless width.positive?
        ::PDF::Reader::TextRun.new(x, sequence.to[1], width, sequence.font_size, sequence.text)
      end

      # Runs on one line that touch become one, as pdf-reader merges them.
      def merge(runs)
        lines = runs.group_by { |run| run.y.to_i }.values
        lines.flat_map { |line| line.sort.each_with_object([]) { |run, merged| join(merged, run) } }.sort
      end

      def join(merged, run)
        return merged << run unless merged.last&.mergable?(run)

        merged[-1] = merged.last + run
      end

      def decode(text)
        return text.dup.force_encoding(Encoding::UTF_8) unless text.b.start_with?(UTF16_BOM)

        text.b.byteslice(2..).force_encoding(Encoding::UTF_16BE).encode(Encoding::UTF_8)
      end
    end
  end
end
