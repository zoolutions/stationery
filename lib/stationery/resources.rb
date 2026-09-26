# frozen_string_literal: true

module Stationery
  # Document-wide names for fonts, images and graphics states, so each is
  # embedded once however many pages use it.
  class Resources
    def initialize
      @fonts = {}
      @images = {}
      @states = {}
    end

    def font(font)
      @fonts[font] ||= :"F#{@fonts.size + 1}"
    end

    def image(image)
      @images[image] ||= :"Im#{@images.size + 1}"
    end

    def opacity(value)
      @states[value.to_f.round(3)] ||= :"GS#{@states.size + 1}"
    end

    # Writes every resource once; returns { category => { name => ref } }.
    def build(writer)
      {
        Font: @fonts.to_h { |font, name| [name, font.build(writer)] },
        XObject: @images.to_h { |image, name| [name, image.build(writer)] },
        ExtGState: @states.to_h { |alpha, name| [name, writer.add({ Type: :ExtGState, ca: alpha, CA: alpha })] }
      }
    end
  end
end
