# frozen_string_literal: true

RSpec.describe Stationery::Images::WebP::Container do
  let(:bitstream) { webp("palette4").byteslice(20, 131) }
  let(:extension) { "\0\0\0\0\x20\0\0\x10\0\0".b } # no flags, a 33x17 canvas

  def fail_with(message) = raise_error(Stationery::UnsupportedImage, message)
  def load(data) = Stationery::Images::WebP.new(data)

  it "finds the bitstream of a bare lossless file" do
    container = described_class.new(webp("palette4"))

    expect(container.bitstream).to eq(bitstream)
    expect(container.canvas).to be_nil
  end

  it "finds the bitstream of an extended file, past the chunks around it" do
    container = described_class.new(webp("extended"))

    expect(container.bitstream).to eq(webp("palette16").byteslice(20..))
    expect(container.canvas).to eq([33, 17])
  end

  it "steps over the padding of a chunk of odd size" do
    data = WebpFactory.riff(WebpFactory.chunk("VP8X", extension), WebpFactory.chunk("ICCP", "odd"),
                            WebpFactory.chunk("VP8L", bitstream), WebpFactory.chunk("XMP ", "<x/>"))

    expect(described_class.new(data).bitstream).to eq(bitstream)
    expect(embedded(load(data))).to eq(embedded(load(webp("palette4"))))
  end

  it "ignores what follows the RIFF chunk" do
    expect(described_class.new("#{webp("palette4")}trailer").bitstream).to eq(bitstream)
  end

  it "refuses lossy WebP by name, with or without alpha" do
    message = "lossy WebP images are not supported, convert to JPEG, PNG or lossless WebP"

    expect { load(File.binread(image_path("webp.webp"))) }.to fail_with(message)
    expect { load(webp("lossy_alpha")) }.to fail_with(message)
  end

  it "refuses animated WebP by name, from the flag or from a frame" do
    message = "animated WebP images are not supported, convert to JPEG, PNG or lossless WebP"
    frames = WebpFactory.riff(WebpFactory.chunk("VP8X", extension), WebpFactory.chunk("ANMF", "\0" * 16))

    expect { load(webp("animated")) }.to fail_with(message)
    expect { load(frames) }.to fail_with(message)
  end

  it "refuses a canvas of another size than the image" do
    data = WebpFactory.riff(WebpFactory.chunk("VP8X", "\0\0\0\0\x20\0\0\x11\0\0"),
                            WebpFactory.chunk("VP8L", bitstream))

    expect { load(data) }.to fail_with("invalid WebP image: canvas and image sizes differ")
  end

  it "refuses an extended header that is too short" do
    data = WebpFactory.riff(WebpFactory.chunk("VP8X", "\0\0\0\0"), WebpFactory.chunk("VP8L", bitstream))

    expect { load(data) }.to fail_with("invalid WebP image: extended header")
  end

  it "refuses a file without image data" do
    expect { load(WebpFactory.riff(WebpFactory.chunk("EXIF", "none"))) }
      .to fail_with("invalid WebP image: no image data")
    expect { load(WebpFactory.riff) }.to fail_with("invalid WebP image: no image data")
  end

  it "refuses a file shorter than it says, or than any WebP" do
    expect { load("RIFF") }.to fail_with("truncated WebP image")
    expect { load(webp("palette4").byteslice(0, 100)) }.to fail_with("truncated WebP image")
  end

  it "refuses a chunk that runs past the end of the file" do
    header = WebpFactory.riff("VP8L")
    oversized = WebpFactory.riff("VP8L#{[200].pack("V")}#{bitstream}")

    expect { load(header) }.to fail_with("truncated WebP image")
    expect { load(oversized) }.to fail_with("truncated WebP image")
  end
end
