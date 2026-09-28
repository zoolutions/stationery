# frozen_string_literal: true

# A flow of paragraphs, nested boxes, lists, floats and runs of floats drawn
# from a seed: the same seed is the same flow, on any machine. Every word is
# written once (`words`) and every float is a grey box or an image (`floats`),
# so a render can be checked against them. Nothing in it is taller than a
# page of 260 pt by itself: a float is at most 120 pt tall and lies three
# boxes deep at most. A float has a width in points, which is the least
# width of the box that holds it.
class RandomFlow
  SIDES = %i[left right].freeze
  KINDS = %i[text text text box list float float run].freeze
  IMAGE = File.expand_path("../fixtures/images/rgb.jpg", __dir__)
  GREY = "#DDDDDD" # of floats only

  attr_reader :seed, :nodes, :words

  def initialize(seed)
    @seed = seed
    @random = Random.new(seed)
    @words = []
    @nodes = children(0, 3..8)
  end

  # Writes the flow with the DSL of `document`.
  def write(document, nodes = @nodes)
    nodes.each do |kind, *rest|
      case kind
      when :text then document.text(rest.first)
      when :box then document.box(**rest.first) { write(document, rest.last) }
      when :list then document.ul { rest.first.each { |item| document.li { write(document, item) } } }
      when :float then float(document, *rest)
      end
    end
  end

  # How many floats of `kind` (:box or :image) it holds.
  def floats(kind, nodes = @nodes)
    nodes.sum do |node|
      case node.first
      when :float then node.last == kind ? 1 : 0
      when :box then floats(kind, node.last)
      when :list then node.last.sum { |item| floats(kind, item) }
      else 0
      end
    end
  end

  private

  def children(depth, count) = Array.new(@random.rand(count)) { pick(depth) }.flatten(1)

  # One node, or the floats of a run.
  def pick(depth)
    kind = KINDS[@random.rand(KINDS.size)]
    kind = :text if depth == 3 && %i[box list].include?(kind)
    case kind
    when :text then [[:text, Array.new(@random.rand(1..30)) { word }.join(" ")]]
    when :box then [[:box, box_options, children(depth + 1, 1..4)]]
    when :list then [[:list, Array.new(@random.rand(1..3)) { children(depth + 1, 1..3) }]]
    when :float then [float_node]
    when :run then Array.new(@random.rand(2..5)) { float_node }
    end
  end

  def word = "w#{@words.size}".tap { |word| @words << word }

  # One float in four is an image.
  def float_node
    [:float, SIDES[@random.rand(2)], @random.rand(40..180), @random.rand(15..120),
     @random.rand(4).zero? ? :image : :box]
  end

  def box_options
    options = { padding: @random.rand(0..8) }
    options[:background] = "#EEEEEE" if @random.rand(3).zero?
    options[:border] = { width: 1 } if @random.rand(3).zero?
    options[:break_inside] = :auto if @random.rand(3).zero?
    options
  end

  def float(document, side, width, height, kind)
    return document.box(float: side, width:, height:, background: GREY) if kind == :box

    document.image(IMAGE, float: side, width:, height:, fit: :cover, alt: false)
  end
end
