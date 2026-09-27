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
        `image(source, width: nil, height: nil, fit: nil, align: nil, opacity: nil, radius: 0, rotate: 0)`

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

        Gradients are approximated in three ways: `reflect` and `repeat` spreads are drawn as `pad`, a gradient
        whose stops differ in opacity uses the first stop's for all of it, and a gradient stroke is drawn in the
        gradient's middle colour. Text glyphs stay upright: a transform moves the text's origin and scales its size
        uniformly, so rotated or skewed text is approximated, and `dominant-baseline` is ignored.

        **Not supported:** `use`, `textPath`, patterns, masks, and stylesheet rules with combinators (`g path`,
        `a > b`), which are ignored and reported.
      MD
    end

    DocsUI::Section("Warnings", description: "Nothing is fetched, nothing silently vanishes.") do
      md <<~'MD'
        - An SVG using elements that cannot be drawn (`use`, `pattern`, …) still renders what it can; the
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
