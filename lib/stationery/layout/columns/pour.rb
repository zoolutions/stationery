# frozen_string_literal: true

module Stationery
  module Layout
    class Columns
      # What one pour placed: a flow per column that took content, and the
      # flow left over (nil when everything was placed).
      Poured = Data.define(:columns, :rest) do
        def complete? = rest.nil?
        def height(width) = columns.map { |column| column.measure(width) }.max || 0
      end

      # Pours a flow into `count` columns of one width: column 1 takes what
      # fits in the height, column 2 continues where it stopped, and so on. A
      # column break is a page break with another height, so every column is
      # cut by Flow#split. A column that places nothing ends the pour, which
      # is what keeps a pour (and every search over pours) finite.
      class Pour
        attr_reader :width, :count

        def initialize(flow, width, count)
          @flow = flow
          @width = width
          @count = count
        end

        # The height of the flow in a single column.
        def total = @flow.measure(@width)

        # `fresh:` is true at the top of a page, where a column keeps a child
        # too tall for it rather than placing nothing.
        def call(height, fresh: false)
          columns = []
          rest = @flow.children.empty? ? nil : @flow
          while rest && columns.size < @count
            head, tail = rest.split(@width, height, fresh:)
            break unless head

            columns << head
            rest = tail
          end
          Poured.new(columns:, rest:)
        end
      end
    end
  end
end
