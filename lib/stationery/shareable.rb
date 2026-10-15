# frozen_string_literal: true

module Stationery
  # `value` deep-frozen, so a constant holding it can be read from any
  # Ractor: Ractor.make_shareable, which also makes a capture-free Proc
  # shareable, or a plain freeze on an engine without Ractor (JRuby,
  # TruffleRuby), where there is nothing to share it with. For the gem's
  # own constants.
  def self.shareable(value) = defined?(::Ractor) ? ::Ractor.make_shareable(value) : value.freeze

  # Settings an app gave at boot, frozen as far as they can be without
  # touching what the app holds: a Hash, an Array or a Data is a frozen copy
  # of its contents settled in turn, a String or a Time a frozen copy, and a
  # block is made shareable when it uses nothing unshareable from around it.
  # Anything else not shareable already (a shaper or an instrumenter that
  # keeps state, a key, a block that closes over the app's state) is kept as
  # it is, never frozen: the main Ractor uses it as before, and a Ractor
  # cannot. Never raises. For Document.finalize!.
  def self.settled(value)
    return value if defined?(::Ractor) && ::Ractor.shareable?(value)

    case value
    when Hash then value.transform_values { settled(it) }.freeze
    when Array then value.map { settled(it) }.freeze
    when String, Time then value.frozen? ? value : value.dup.freeze
    when Data then value.with(**value.to_h.transform_values { settled(it) })
    when Proc then settled_block(value)
    else value
    end
  end

  # A capture-free block made shareable where it is, which leaves it as it
  # was when it cannot be: Ractor.make_shareable checks what the block uses
  # before it changes anything.
  def self.settled_block(block)
    defined?(::Ractor) ? ::Ractor.make_shareable(block) : block
  rescue ::Ractor::Error
    block
  end
  private_class_method :settled_block
end
