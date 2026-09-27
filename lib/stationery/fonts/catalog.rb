# frozen_string_literal: true

module Stationery
  module Fonts
    # Font packs `stationery fonts install` can put in vendor/fonts. Each file
    # is [url, sha256, filename]; a URL with a `#member` fragment names a file
    # inside a .tar.gz, and a nil URL copies the file bundled with the gem.
    # `rake fonts:verify` downloads everything and checks the SHAs.
    module Catalog
      Pack = Data.define(:key, :family, :license, :files, :license_file)

      NOTO = "https://raw.githubusercontent.com/notofonts/notofonts.github.io/" \
             "f145d86c53996717bc4c25d4602eb9294e43dccc/fonts"
      NOTO_OFL = ["https://raw.githubusercontent.com/notofonts/latin-greek-cyrillic/NotoSans-v2.015/OFL.txt",
                  "cee9892f9f0cc8fe882c9e9537ee6a89621d86ee7ceaf70b02e2b2b1c25c061a", "OFL.txt"].freeze
      LIBERATION = "https://github.com/liberationfonts/liberation-fonts/files/7261482/" \
                   "liberation-fonts-ttf-2.1.5.tar.gz#liberation-fonts-ttf-2.1.5"
      LIBERATION_OFL = ["#{LIBERATION}/LICENSE",
                        "93fed46019c38bbe566b479d22148e2e8a1e85ada614accb0211c37b2c61c19b", "OFL.txt"].freeze
      LIBERATION_LICENSE = 'OFL-1.1, Reserved Font Name "Liberation"'

      # { style => [url, sha, "Family-Style.ttf"] } with the URL built from the file name.
      def self.faces(family, shas)
        shas.to_h do |style, sha|
          file = "#{family}-#{style.to_s.split("_").map(&:capitalize).join}.ttf"
          [style, [yield(file), sha, file].freeze]
        end.freeze
      end

      def self.noto(family, shas) = faces(family, shas) { "#{NOTO}/#{family}/unhinted/ttf/#{it}" }
      def self.liberation(family, shas) = faces(family, shas) { "#{LIBERATION}/#{it}" }
      private_class_method :faces, :noto, :liberation

      PACKS = [
        Pack.new(
          key: :inter, family: "Inter", license: "OFL-1.1",
          files: {
            regular: [nil, "40d692fce188e4471e2b3cba937be967878f631ad3ebbbdcd587687c7ebe0c82", "Inter-Regular.ttf"],
            bold: [nil, "288316099b1e0a47a4716d159098005eef7c0066921f34e3200393dbdb01947f", "Inter-Bold.ttf"],
            italic: [nil, "bbc051dd204b5019a1aa0bc0ae2aa8a05ab13e7a3f979fa357631dc7feb6833a", "Inter-Italic.ttf"],
            bold_italic: [nil, "948405a16cdc62701da5f4005ed068ca5f4d27061d98f7974ccfc37831d9581d",
                          "Inter-BoldItalic.ttf"]
          },
          license_file: [nil, "262481e844521b326f5ecd053e59b98c8b2da78c8ee1bdbb6e8174305e54935a", "OFL.txt"]
        ),
        Pack.new(
          key: :noto_sans, family: "Noto Sans", license: "OFL-1.1", license_file: NOTO_OFL,
          files: noto("NotoSans",
                      regular: "f3961a9cde016d41a4879aecda1474d3a36d6bf54fa0e4643de029cc2248b0e8",
                      bold: "87cb2d84472a7d66da659ee47b6cdb9552326e8c128245231f191b6ac72529d9",
                      italic: "678288f868807d4d64a6f3b51466871d117d915780381ce9d0ed4b3bcbd06d37",
                      bold_italic: "3d367743f371f28671d2764e911a53d7c20ec9b6aa8791d059e7090389fc52a5")
        ),
        Pack.new(
          key: :noto_serif, family: "Noto Serif", license: "OFL-1.1", license_file: NOTO_OFL,
          files: noto("NotoSerif",
                      regular: "a15cfbbc1539d707115111d672d590a3d70d4f74b4c0a315956da20ae19a14e1",
                      bold: "24ad531e6b05ddad8c3d89572d2c93eb86a6b74e652ce7ee3c3e171de68e84c3",
                      italic: "c4b3c971741ecdb40f5a443bce754e8fe91efe761b6ea10c92be7c3597cdadc4",
                      bold_italic: "1bc4f86502eaa368718f6192bee022ea9a703d5af1c18b7d291212657b63074a")
        ),
        Pack.new(
          key: :noto_sans_mono, family: "Noto Sans Mono", license: "OFL-1.1", license_file: NOTO_OFL,
          files: noto("NotoSansMono",
                      regular: "87f8ce0522a6c99b743ee5fc75b4073cfdd575639119672828b7b9944b65b4f4",
                      bold: "1100772b2f79c102402a1011df5e2226517d0f40ac553a25fb12fdbad8c11b85")
        ),
        Pack.new(
          key: :liberation_sans, family: "Liberation Sans", license: LIBERATION_LICENSE, license_file: LIBERATION_OFL,
          files: liberation("LiberationSans",
                            regular: "76d04c18ea243f426b7de1f3ad208e927008f961dc5945e5aad352d0dfde8ee8",
                            bold: "788abee4c806d660e8aee46689dd8540cd4bb98da03dcc9d171ce3efd99a9173",
                            italic: "e5bae5c4cde31f22142753855f4f8fb86da6ff39955ed3c0a11248b0d16948b0",
                            bold_italic: "698da70fc191cc5f33ad4d6d3fe830fe4624b898ea2e3169955928b7c491f1ee")
        ),
        Pack.new(
          key: :liberation_serif, family: "Liberation Serif", license: LIBERATION_LICENSE,
          license_file: LIBERATION_OFL,
          files: liberation("LiberationSerif",
                            regular: "058ea80864aef09a23f45cbec2bb5400bc3dfbdea01c3f10538a21fcb497fb74",
                            bold: "d754ba427cfe0bca54ae052384baa8f842da5bd6550ad4da024ac441e7a7d5ce",
                            italic: "0e3dea9f8d613e006ccfa62201f33e265d19167bd0907725c3e145368b04fc2e",
                            bold_italic: "f17db8af71e24d2066b587546021d4f0b296be389512b658dec3c09affeb11a7")
        ),
        Pack.new(
          key: :liberation_mono, family: "Liberation Mono", license: LIBERATION_LICENSE, license_file: LIBERATION_OFL,
          files: liberation("LiberationMono",
                            regular: "f2b83c763e8afd21709333370bed4774337fae82267937e2b5aea7e2fbd922c1",
                            bold: "bd62a0672d0b9b6710b01df434c80ad54fa5f0835207eb7b17b7a761463067bb",
                            italic: "605c01c711b44480a7508d349dfbf3264e81fa43d69e61cfa7d10b86e764c4d1",
                            bold_italic: "79451f3c09fe25116098853b7a2ca6e2436220ccc11af022979adbcf195be130")
        )
      ].freeze

      def self.fetch(key)
        PACKS.find { |pack| pack.key.to_s == key.to_s } ||
          raise(Error, "unknown font pack #{key.to_s.inspect} (available: #{PACKS.map(&:key).join(", ")})")
      end
    end
  end
end
