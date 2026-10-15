# frozen_string_literal: true

# Runs an example on a fresh boot: no font paths yet, no instrumenter set,
# nothing finalized. What the suite had is put back after, so an example
# that runs Stationery.finalize! leaves the font paths appendable, and every
# document class loaded so far as it was, for the rest.
module BootState
  def self.around
    font_paths = Stationery.font_paths
    instrumenter = Stationery::Instrumentation.instance_variable_get(:@instrumenter)
    configs = documents(Stationery::Document).to_h { [it, it.config] }
    Stationery.instance_variable_set(:@font_paths, [])
    Stationery::Instrumentation.instance_variable_set(:@instrumenter, nil)
    yield
  ensure
    Stationery.instance_variable_set(:@font_paths, font_paths)
    Stationery::Instrumentation.instance_variable_set(:@instrumenter, instrumenter)
    configs.each { |document, config| document.instance_variable_set(:@config, config) }
  end

  def self.documents(klass) = klass.subclasses.flat_map { [it, *documents(it)] }
end
