# frozen_string_literal: true

module Stationery
  module Raster
    # Turns polygons in device pixels (flat Arrays of x, y, each closed back
    # to its first point) into the Spans they cover on a `width` × `height`
    # surface, under the nonzero rule or the even-odd one.
    #
    # Each row is crossed by sample lines, and each sample line by the edges
    # of the polygons: the crossings sorted by x, with the winding each
    # adds, give the stretches inside. Without anti-aliasing there is one
    # line through the middle of the row and a pixel is in when its centre
    # is (a one-bit printer's rule, and poppler's in mono). With it there are
    # SAMPLES lines and each stretch covers the pixels at its ends by the
    # share of them it reaches, so coverage is exact across a row and in
    # quarters down it (poppler's anti-aliasing samples 4 × 4).
    class Scanner
      SAMPLES = 4
      WEIGHT = 1.0 / SAMPLES
      # Coverage below this is none, above 1 - it all.
      FAINT = 1.0 / 512

      def initialize(width, height, antialias:)
        @width = width
        @height = height
        @antialias = antialias
      end

      def spans(polygons, even_odd: false)
        edges = edges(polygons)
        return Spans.new(0, []) if edges.empty?

        top = [edges.first[0].floor, 0].max
        bottom = [edges.map { |edge| edge[1] }.max.ceil, @height].min
        return Spans.new(0, []) if bottom <= top

        rows = @antialias ? smooth(edges, top, bottom, even_odd) : sharp(edges, top, bottom, even_odd)
        Spans.new(top, rows)
      end

      private

      # [top, bottom, x at top, dx per dy, winding] per edge that is not
      # level, by top.
      def edges(polygons)
        edges = []
        polygons.each do |points|
          count = points.size
          next if count < 6

          x0 = points[count - 2]
          y0 = points[count - 1]
          i = 0
          while i < count
            x1 = points[i]
            y1 = points[i + 1]
            if y1 > y0 then edges << [y0, y1, x0, (x1 - x0) / (y1 - y0).to_f, 1]
            elsif y1 < y0 then edges << [y1, y0, x1, (x0 - x1) / (y0 - y1).to_f, -1]
            end
            x0 = x1
            y0 = y1
            i += 2
          end
        end
        edges.sort_by!(&:first)
      end

      def sharp(edges, top, bottom, even_odd)
        scan = Sweep.new(edges)
        (top...bottom).map do |y|
          row = []
          scan.inside(y + 0.5, even_odd) do |xa, xb|
            x0 = (xa - 0.5).ceil.clamp(0, @width)
            x1 = (xb - 0.5).ceil.clamp(0, @width)
            row.push(x0, x1, 1.0) if x1 > x0
          end
          row
        end
      end

      def smooth(edges, top, bottom, even_odd)
        scan = Sweep.new(edges)
        cover = Hash.new(0.0)
        (top...bottom).map do |y|
          cover.clear
          SAMPLES.times do |k|
            scan.inside(y + ((k + 0.5) * WEIGHT), even_odd) { |xa, xb| accumulate(cover, xa, xb) }
          end
          runs(cover)
        end
      end

      # Adds a stretch as changes of coverage: from the pixel it starts in,
      # by the share of it inside, and back down at the pixel it ends in.
      def accumulate(cover, from, to)
        from = 0.0 if from.negative?
        to = @width.to_f if to > @width
        return if to <= from

        start = from.floor
        part = from - start
        cover[start] += (1 - part) * WEIGHT
        cover[start + 1] += part * WEIGHT if part.positive?
        stop = to.floor
        part = to - stop
        cover[stop] -= (1 - part) * WEIGHT
        cover[stop + 1] -= part * WEIGHT if part.positive?
      end

      # The runs of a row from its changes of coverage.
      def runs(cover)
        row = []
        coverage = 0.0
        previous = nil
        cover.keys.sort!.each do |x|
          if previous && coverage > FAINT && previous < @width
            value = coverage > 1 - FAINT ? 1.0 : coverage
            stop = [x, @width].min
            if !row.empty? && row[-2] == previous && row[-1] == value
              row[-2] = stop
            else
              row.push(previous, stop, value)
            end
          end
          coverage += cover[x]
          previous = x
        end
        row
      end

      # The edges a sample line crosses, taken on as the line moves down.
      class Sweep
        def initialize(edges)
          @edges = edges
          @next = 0
          @active = []
        end

        # Yields the start and end x of each stretch of line `y` inside.
        def inside(y, even_odd)
          while @next < @edges.size && @edges[@next][0] <= y
            @active << @edges[@next]
            @next += 1
          end
          @active.reject! { |edge| edge[1] <= y }
          return if @active.empty?

          crossings = @active.map { |edge| [edge[2] + ((y - edge[0]) * edge[3]), edge[4]] }
          crossings.sort_by!(&:first)
          winding = 0
          start = nil
          crossings.each do |x, dir|
            was = even_odd ? winding.odd? : winding != 0
            winding += dir
            now = even_odd ? winding.odd? : winding != 0
            if now && !was then start = x
            elsif was && !now then yield start, x
            end
          end
        end
      end
    end
  end
end
