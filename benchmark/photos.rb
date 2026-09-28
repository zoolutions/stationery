# frozen_string_literal: true

# A cover photo and six illustrated sections, three pages: the same document
# in Prawn (whose `image` fits rather than crops, the closest it offers to
# `fit: :cover`) and, when installed, sghtmltopdf.
#
#   bundle exec ruby -Ilib benchmark/photos.rb
require_relative "support"

module Bench
  def self.prawn_photos
    pdf = Prawn::Document.new(page_size: "A4", margin: 48)
    prawn_fonts(pdf)
    pdf.image COVER, width: 499, height: 200
    6.times do
      pdf.text "Healthy Living", size: 16, style: :bold
      3.times { pdf.text PARAGRAPH, size: 9.5 }
      top = pdf.cursor
      PHOTOS.each_with_index do |photo, index|
        pdf.image photo, at: [index * 169, top], fit: [161, 90]
      end
      pdf.move_down 100
    end
    pdf.render
  end
end

if $PROGRAM_NAME == __FILE__
  Bench.compare({ "stationery" => -> { Bench::StationeryPhotos.new.to_pdf }, "prawn" => -> { Bench.prawn_photos } },
                html: Bench::HTML.photos)
end
