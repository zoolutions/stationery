# frozen_string_literal: true

# Runs an example on a fresh boot: no font paths yet, no instrumenter set,
# nothing finalized. What the suite had is put back after, so an example
# that runs Stationery.finalize! leaves the font paths appendable for the rest.
module BootState
  def self.around
    font_paths = Stationery.font_paths
    instrumenter = Stationery::Instrumentation.instance_variable_get(:@instrumenter)
    Stationery.instance_variable_set(:@font_paths, [])
    Stationery::Instrumentation.instance_variable_set(:@instrumenter, nil)
    yield
  ensure
    Stationery.instance_variable_set(:@font_paths, font_paths)
    Stationery::Instrumentation.instance_variable_set(:@instrumenter, instrumenter)
  end
end
