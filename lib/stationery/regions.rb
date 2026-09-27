# frozen_string_literal: true

module Stationery
  # A header or footer declaration: which slot, how much space it reserves
  # (nil = measured), the gap to the body, the pages it applies to and the
  # block that draws it.
  Region = Data.define(:slot, :height, :gap, :on, :block)

  # A document's header and footer declarations. Later declarations win for
  # the pages they match; a region without a height is measured once, at the
  # first page that asks for it.
  class Regions
    SELECTORS = %i[all first rest odd even last].freeze
    SLOTS = %i[header footer].freeze

    def self.validate!(on)
      return on if SELECTORS.include?(on) || on.is_a?(Integer) || on.is_a?(Range) || on.respond_to?(:call)

      raise ArgumentError, "on: takes #{SELECTORS.map(&:inspect).join(", ")}, a page number, a range or a proc, " \
                           "got #{on.inspect}"
    end

    def self.matches?(on, number, last: false)
      case on
      when :all then true
      when :first then number == 1
      when :rest then number > 1
      when :odd then number.odd?
      when :even then number.even?
      when :last then last
      when Integer then number == on
      when Range then on.cover?(number)
      else on.call(number)
      end
    end

    def initialize(entries, measure:)
      @entries = entries
      @measure = measure
      @heights = {}.compare_by_identity
      @last = entries.any? { |entry| entry.on == :last }
    end

    def entry_for(slot, number, last: false)
      @entries.reverse_each.find { |entry| entry.slot == slot && self.class.matches?(entry.on, number, last:) }
    end

    # [top, bottom] points taken from the body on page `number`.
    def reserve(number, last: false)
      SLOTS.map do |slot|
        entry = entry_for(slot, number, last:)
        height = entry ? height_of(entry, number) : 0
        height.positive? ? height + entry.gap : 0
      end
    end

    # Whether page `number` would reserve different space as the last page.
    def last_sensitive?(number) = @last && reserve(number, last: true) != reserve(number)

    def height_of(entry, number)
      return entry.height if entry.height
      return 0 unless entry.block

      @heights[entry] ||= @measure.call(entry, number)
    end
  end
end
