# frozen_string_literal: true

require "stationery/rich/nodes"

# Terse constructors for the rich-text block model in parser specs.
module RichHelpers
  R = Stationery::Rich

  def txt(text, **marks) = R::Inline.new(text:, marks:)
  def br = R::Inline.break
  def inlines(*items) = items.map { |item| item.is_a?(String) ? txt(item) : item }
  def para(*items) = R::Paragraph.new(inlines: inlines(*items))
  def heading(level, *items) = R::Heading.new(level:, inlines: inlines(*items))
  def bullets(*items) = R::List.new(ordered: false, start: nil, items:)
  def numbers(start, *items) = R::List.new(ordered: true, start:, items:)
  def quote(*blocks) = R::Blockquote.new(blocks:)
  def code_block(text, language = nil) = R::CodeBlock.new(text:, language:)
  def rule = R::Rule.new
  def image(src, alt = nil, width: nil, height: nil) = R::Image.new(src:, alt:, width:, height:)
  def table(*rows) = R::Table.new(rows:)
  def cell(*blocks, header: false, align: nil) = R::Cell.new(header:, align:, blocks:)
end

RSpec.configure do |config|
  config.include RichHelpers
  config.extend RichHelpers
end
