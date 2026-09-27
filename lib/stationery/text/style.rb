# frozen_string_literal: true

module Stationery
  module Text
    SCRIPT_SCALE = 0.583

    # How a run of text looks. Immutable; derive variants with #with.
    Style = Data.define(:family, :size, :weight, :style, :color, :letter_spacing,
                        :underline, :strikethrough, :script, :link, :opacity, :kerning) do
      def initialize(family:, size: 10, weight: :regular, style: :normal, color: "#000000", letter_spacing: 0,
                     underline: false, strikethrough: false, script: nil, link: nil, opacity: nil, kerning: true)
        super
      end

      # The size glyphs are drawn at: smaller for sub- and superscript.
      def render_size
        script ? size * SCRIPT_SCALE : size
      end

      # Baseline shift for sub- and superscript.
      def rise
        case script
        when :sup then size * 0.33
        when :sub then -size * 0.15
        else 0
        end
      end
    end

    # A piece of text in one style.
    Run = Data.define(:text, :style) do
      # Joins neighbouring runs that share a style.
      def self.merge(runs)
        runs.each_with_object([]) do |run, merged|
          next if run.text.empty?

          if merged.last&.style == run.style
            merged[-1] = Run.new(merged.last.text + run.text, run.style)
          else
            merged << run
          end
        end
      end
    end
  end
end
