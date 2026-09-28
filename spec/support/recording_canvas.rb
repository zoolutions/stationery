# frozen_string_literal: true

# A canvas of no output: it includes Canvas::Interface, implements what a
# canvas has to and records what it is asked to draw, as [name, …] in `calls`.
# It has no `page`, no `num` and no resources, and its paths are
# Stationery::Path, so whatever reaches for the PDF canvas raises on it.
class RecordingCanvas
  include Stationery::Canvas::Interface

  attr_reader :calls

  def initialize(page, calls, template: false, warnings: nil, debug: false)
    @page = page
    @calls = calls
    @template = template
    @warnings = warnings
    @debug = debug
  end

  def save
    @calls << [:save]
    yield self
  end

  def transform(matrix)
    @calls << [:transform, matrix]
    yield self
  end

  def clip_to(paths, even_odd: false)
    paths = paths.reject(&:empty?)
    return if paths.empty?

    @calls << [:clip_to, paths.map { |path| path.each_segment.to_a }, even_odd]
    yield self
  end

  def draw(path, **options)
    @calls << [:draw, path.each_segment.to_a, options]
  end

  def shade_path(path, shading, **options)
    @calls << [:shade_path, path.each_segment.to_a, shading, options]
  end

  def image(image, **options)
    @calls << [:image, image, options]
  end

  def glyphs(run, x, y, **options)
    @calls << [:glyphs, run, x, y, options]
  end
end

# The canvases of a render that records: what Document#paint_on is handed.
# `calls` is every call by page, in the order the pages were first painted.
class RecordingCanvases
  attr_reader :calls

  def initialize(warnings: nil, debug: false)
    @warnings = warnings
    @debug = debug
    @calls = {}.compare_by_identity
  end

  def body(page) = canvas(page)

  def template(page, layer = :foreground)
    calls_of(page) << [:layer, layer]
    yield canvas(page, template: true)
  end

  def over(page) = canvas(page)

  # Every call on every page, [name, …] each.
  def all = @calls.values.flatten(1)

  # The texts drawn, in order.
  def texts
    runs = all.select { |name, *| name == :glyphs }.map { |_, run| run }
    runs.map { |run| (run.respond_to?(:chars) ? run.chars : run.texts.values).join }
  end

  private

  def calls_of(page) = @calls[page] ||= []

  def canvas(page, template: false)
    RecordingCanvas.new(page, calls_of(page), template:, warnings: @warnings, debug: @debug)
  end
end
