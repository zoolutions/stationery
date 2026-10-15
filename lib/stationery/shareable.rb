# frozen_string_literal: true

module Stationery
  # `value` deep-frozen, so a constant holding it can be read from any
  # Ractor: Ractor.make_shareable, which also makes a capture-free Proc
  # shareable, or a plain freeze on an engine without Ractor (JRuby,
  # TruffleRuby), where there is nothing to share it with. For the gem's
  # own constants.
  def self.shareable(value) = defined?(::Ractor) ? ::Ractor.make_shareable(value) : value.freeze
end
