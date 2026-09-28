# frozen_string_literal: true

class Views::Docs::Pages::ImagesAndSvg < DocsUI::Page
  title "Images and SVG"
  eyebrow "Guide"

  def lead = "JPEG and PNG images with aspect-preserving sizing, and the SVG subset icon sets use — drawn as vectors."

  def content
    DocsUI::Section("Formats", description: "Decoded in Ruby, cached per process.") do
      md <<~'MD'
        Images are **JPEG** (grey, RGB, CMYK) and **PNG** (every colour type, alpha as a soft mask, palette
        transparency). The source is a file path or any IO (`StringIO`, an ActiveStorage download, …).
        Parsed fonts and images are cached per process, keyed by content, so the same logo on every page is
        embedded once.
      MD
    end

    DocsUI::Section("Sizing and fit") do
      md <<~'MD'
        `image(source, width: nil, height: nil, fit: nil, align: nil, opacity: nil, radius: 0, rotate: 0, max_ppi: 300, downscale: false)`

        | Given | Result |
        | --- | --- |
        | nothing | one pixel is one point |
        | `width:` or `height:` | the other side follows the aspect ratio |
        | both | exactly that size |
        | `fit: [w, h]` | scaled to fit inside the box, aspect preserved |
        | `fit: :cover` with `width:` and `height:` | scaled to fill the box, aspect preserved, the excess cropped around the centre (CSS `object-fit: cover`) |
        | `radius:` | corners rounded by that many points (the image is clipped) |
        | `rotate:` | turned that many degrees clockwise around its centre; the space it takes up does not change (CSS `transform: rotate`) |

        An image is never wider than the space it is given; it scales down to the column. `align:`
        (`:left`, `:center`, `:right`) positions a narrower image.

        ```ruby
        image "logo.png", height: 34, align: :right
        image StringIO.new(product.photo.download), fit: [120, 80]
        # a tilted, rounded snapshot cropped to 4:3
        image photo, width: 160, height: 120, fit: :cover, radius: 8, rotate: -3
        ```

        A rotated image paints outside its rectangle at the corners, so leave room around it (a
        `box(padding:)`).
      MD
    end

    DocsUI::Section("Resolution", description: "Bitmaps keep their pixels.") do
      md <<~'MD'
        A JPEG is embedded byte for byte and a PNG re-encoded losslessly, so a 1600 px photo drawn
        160 pt wide ships all 1600 px at 720 ppi. Print needs about 300 ppi (`width_in_points / 72 * 300`
        pixels: a 160 pt photo wants about 670 px) and screen PDFs half that.

        Every image is checked when it is painted: drawn at more than twice `max_ppi:` it is reported
        as a [`Warnings::OversizedImage`](/docs/warnings) naming the file, its pixel width and the
        resolution it lands at, so `strict` catches it.

        ```ruby
        class Flyer < Stationery::Document
          images max_ppi: 300, downscale: true   # document defaults; nil switches the check off
        end

        image "photo.png", width: 160                 # a 1600 px PNG is resampled to 667 px
        image "photo.jpg", width: 160, max_ppi: nil   # this one is fine as it is
        ```

        `downscale: true` resamples a **PNG** to `max_ppi` at its drawn size with a box filter (alpha
        and palette transparency included) and embeds that; the layout, the tagged `Figure` and the
        text around it do not change. A **JPEG** is never re-encoded, so it only warns: size JPEGs
        before you embed them. With ActiveStorage, make a JPEG variant per drawn size
        (`resize_to_limit`, quality 75) and preprocess it, so a render only downloads. A 10-page flyer
        with 18 photos went from 3.3 MB to under 1 MB that way with no visible difference.
      MD
    end

    DocsUI::Section("SVG", description: "Icons and simple drawings as vectors.") do
      md <<~'MD'
        `svg(source_or_path, width: nil, height: nil, color: "#000000", align: nil)` takes SVG markup or a path
        to a `.svg` file. `currentColor` takes `color:`, so one icon file serves every theme colour.

        ```ruby
        CHECK = <<~SVG
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
            <circle cx="12" cy="12" r="11" fill="currentColor"/>
            <path d="M7 12.5l3 3 7-7" fill="none" stroke="#fff" stroke-width="2.2"
                  stroke-linecap="round" stroke-linejoin="round"/>
          </svg>
        SVG

        row { column(width: 16) { svg CHECK, width: 14, color: "#0F766E" }; column { text "Shipped" } }
        ```

        **Supported:** `path` (every command, including arcs), `rect` (with `rx`/`ry`), `circle`, `ellipse`,
        `line`, `polyline`, `polygon` and `g`, with fill, stroke, line caps and joins, `fill-rule`, opacity,
        inline `style` attributes, `<style>` stylesheets (element, `.class`, `#id`, `element.class`, comma lists and
        `*` selectors; presentation attributes < rules by specificity < inline `style`; `display: none` and
        `visibility: hidden` skip elements), `transform` (`matrix`, `translate`, `scale`, `rotate`, `skewX`, `skewY`),
        `currentColor`, `linearGradient`/`radialGradient` fills (stops, `href` chains, both gradient units,
        `gradientTransform`), and `text`/`tspan` (`x`, `y`, `dx`, `dy`, `font-family`, `font-size`, `font-weight`,
        `font-style`, `text-anchor`, `fill`, `opacity`). SVG text uses the document's fonts: the first
        `font-family` the document knows (registered, bundled or an installed pack), otherwise its default family.

        **Sprites and viewports:** `use` (`href` or `xlink:href`) draws a shape, a group, a text, a `symbol`
        or another `use` at its `x`/`y`, under its own `transform`; its presentation attributes are
        inherited by what it draws, where the referenced element's own attributes win. A `symbol` is drawn
        only through `use`, into a viewport of the use's `width`/`height` (the viewport around it without
        them): its `viewBox` is fitted by `preserveAspectRatio` (`none`, `xMin`/`xMid`/`xMax` with
        `YMin`/`YMid`/`YMax`, `meet` or `slice`) and what overflows is clipped unless `overflow="visible"`. A
        nested `svg` is the same viewport at its own `x`/`y`. The `color` property sets what `currentColor`
        means from an element down, so one symbol serves every colour:

        ```ruby
        SPRITE = <<~SVG
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 60 24">
            <symbol id="check" viewBox="0 0 24 24">
              <path d="M4 12l6 6L20 6" fill="none" stroke="currentColor" stroke-width="2"/>
            </symbol>
            <use href="#check" width="24" height="24"/>
            <use href="#check" x="36" y="4" width="16" height="16" color="#16A34A"/>
          </svg>
        SVG

        svg SPRITE, width: 120, color: "#111827"
        ```

        **Clipping:** `clip-path="url(#id)"` (attribute or style) on a shape, a group, a text or a `use` paints
        it inside the `clipPath`'s shapes: `path`, `rect`, `circle`, `ellipse`, `polygon`, `polyline` and `use`
        children that refer to one, each under its own `transform` and the clip path's, with `clip-rule`.
        `clipPathUnits="objectBoundingBox"` scales them to the box of the clipped element, and a `clip-path` on
        the `clipPath` itself intersects. The shapes join into one clipping path, so overlapping shapes wound
        in opposite directions cancel where they overlap; text inside a `clipPath` is skipped and reported.

        Gradients are approximated in three ways: `reflect` and `repeat` spreads are drawn as `pad`, a gradient
        whose stops differ in opacity uses the first stop's for all of it, and a gradient stroke is drawn in the
        gradient's middle colour. Text glyphs stay upright: a transform moves the text's origin and scales its size
        uniformly, so rotated or skewed text is approximated, and `dominant-baseline` is ignored.

        **Not supported:** `image`, `mask`, `pattern`, `filter`, `textPath`, and stylesheet rules with combinators
        (`g path`, `a > b`), which are ignored and reported. So are a `use` whose target is missing or that
        refers back to itself (`use: #id not found`, `use: circular reference #id`) and a `clip-path` without
        its `clipPath` (`clip-path: #id not found`, drawn unclipped).
      MD
    end

    DocsUI::Section("Warnings", description: "Nothing is fetched, nothing silently vanishes.") do
      md <<~'MD'
        - An SVG using elements that cannot be drawn (`mask`, `pattern`, …) still renders what it can; the
          elements are listed in `SVG::Document#unsupported` and reported as an `UnsupportedSvg` warning, as
          are references to missing gradients (`url(#id)`) and gradient spreads drawn as `pad`.
        - In `html` and `markdown`, images come from `images:` or from files under `base_path:`. Sources that
          resolve nowhere, point outside `base_path` or are remote URLs are skipped with a `SkippedImage`
          warning. Nothing is ever fetched over the network.

        See [Warnings and strict mode](/docs/warnings) to turn these into failures.
      MD
    end
  end
end
