# frozen_string_literal: true

require "strscan"

module Stationery
  module SVG
    class Error < Stationery::Error; end

    # Parses SVG path data into absolute segments:
    #
    #   [:move, x, y] [:line, x, y] [:curve, x1, y1, x2, y2, x, y] [:close]
    #
    # Quadratic curves become cubics and elliptical arcs become cubic segments
    # of at most 90 degrees, so a drawing backend needs only move, line, curve
    # and close.
    class PathData
      ARITY = { "M" => 2, "L" => 2, "T" => 2, "H" => 1, "V" => 1, "C" => 6, "S" => 4, "Q" => 4, "A" => 7,
                "Z" => 0 }.freeze
      NUMBER = /[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?/
      FLAG = /[01]/
      SEPARATORS = /[\s,]*/

      def self.parse(data) = new(data).segments

      def initialize(data)
        @scanner = StringScanner.new(data.to_s)
        @segments = []
        @x = @y = @start_x = @start_y = 0
        @control = nil
        @command = nil
      end

      def segments
        loop do
          @scanner.skip(SEPARATORS)
          break if @scanner.eos?

          if (letter = @scanner.scan(/[MmLlHhVvCcSsQqTtAaZz]/))
            @command = letter
            next close_path if letter.upcase == "Z"
          end
          raise Error, "unreadable path data near #{@scanner.rest[0, 12].inspect}" unless @command

          apply(@command, arguments(@command))
        end
        @segments
      end

      private

      def arguments(command)
        Array.new(ARITY.fetch(command.upcase)) do |index|
          @scanner.skip(SEPARATORS)
          token = @scanner.scan(command.upcase == "A" && [3, 4].include?(index) ? FLAG : NUMBER)
          raise Error, "unreadable path data near #{@scanner.rest[0, 12].inspect}" unless token

          number(token)
        end
      end

      def number(token)
        token.match?(/[.eE]/) ? token.to_f : token.to_i
      end

      def apply(command, args)
        relative = command == command.downcase
        case command.upcase
        when "M" then move(*absolute(args, relative))
        when "L" then line(*absolute(args, relative))
        when "H" then line(relative ? @x + args[0] : args[0], @y)
        when "V" then line(@x, relative ? @y + args[0] : args[0])
        when "C" then curve(*absolute(args, relative))
        when "S" then curve(*reflected_control, *absolute(args, relative))
        when "Q" then quadratic(*absolute(args, relative))
        when "T" then quadratic(*reflected_control, *absolute(args, relative))
        else arc(*args.first(5), *absolute(args.last(2), relative))
        end
      end

      def absolute(args, relative)
        return args unless relative

        args.each_with_index.map { |value, index| value + (index.even? ? @x : @y) }
      end

      def move(x, y)
        @segments << [:move, x, y]
        @x = @start_x = x
        @y = @start_y = y
        @control = nil
        # Coordinates after a move are implicit lines.
        @command = @command == "m" ? "l" : "L"
      end

      def line(x, y)
        @segments << [:line, x, y]
        @x = x
        @y = y
        @control = nil
      end

      def curve(x1, y1, x2, y2, x, y)
        @segments << [:curve, x1, y1, x2, y2, x, y]
        @x = x
        @y = y
        @control = [x2, y2]
      end

      def quadratic(qx, qy, x, y)
        curve(@x + ((2 * (qx - @x)) / 3.0), @y + ((2 * (qy - @y)) / 3.0),
              x + ((2 * (qx - x)) / 3.0), y + ((2 * (qy - y)) / 3.0), x, y)
        @control = [qx, qy]
      end

      def reflected_control
        return [@x, @y] unless @control

        [(2 * @x) - @control[0], (2 * @y) - @control[1]]
      end

      def close_path
        @segments << [:close]
        @x = @start_x
        @y = @start_y
        @control = nil
      end

      def arc(rx, ry, rotation, large, sweep, x, y)
        return line(x, y) if rx.zero? || ry.zero?

        Arc.new(@x, @y, rx.abs, ry.abs, rotation, large, sweep, x, y).curves.each { |c| curve(*c) }
        @x = x
        @y = y
      end
    end
  end
end
