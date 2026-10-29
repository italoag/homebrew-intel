class Harfbuzz < Formula
  desc "OpenType text shaping engine"
  homepage "https://github.com/harfbuzz/harfbuzz"
  url "https://github.com/harfbuzz/harfbuzz/releases/download/15.0.0/harfbuzz-15.0.0.tar.xz"
  sha256 "968536e9abd782f07f7954044c0c4020199fcdd39b41d221ec42d2a3be4a44df"
  license "MIT"
  revision 1
  compatibility_version 1
  head "https://github.com/harfbuzz/harfbuzz.git", branch: "main"


  depends_on "italoag/intel/gobject-introspection" => :build
  depends_on "italoag/intel/meson" => :build
  depends_on "italoag/intel/ninja" => :build
  depends_on "italoag/intel/pkgconf" => :build
  depends_on "italoag/intel/python@3.15" => [:build, :test]
  depends_on "italoag/intel/pygobject3" => :test
  depends_on "italoag/intel/cairo"
  depends_on "italoag/intel/freetype"
  depends_on "italoag/intel/glib"
  depends_on "italoag/intel/graphite2"
  depends_on "italoag/intel/icu4c@79"
  depends_on "italoag/intel/libpng"

  on_linux do
    depends_on "zlib-ng-compat"
  end

  resource "homebrew-test-ttf", :test do
    url "https://github.com/harfbuzz/harfbuzz/raw/fc0daafab0336b847ac14682e581a8838f36a0bf/test/shaping/fonts/sha1sum/270b89df543a7e48e206a2d830c0e10e5265c630.ttf"
    sha256 "9535d35dab9e002963eef56757c46881f6b3d3b27db24eefcc80929781856c77"
  end

  # downloads test resources
  allow_network_access! :test

  def install
    args = %w[
      --default-library=both
      -Dcairo=enabled
      -Dcoretext=enabled
      -Dfreetype=enabled
      -Dglib=enabled
      -Dgobject=enabled
      -Dgraphite=enabled
      -Dicu=enabled
      -Dintrospection=enabled
      -Dtests=disabled
    ]

    system "meson", "setup", "build", *args, *std_meson_args
    system "meson", "compile", "-C", "build", "--verbose"
    system "meson", "install", "-C", "build"
  end

  test do
    resource("homebrew-test-ttf").stage do
      shape = pipe_output("#{bin}/hb-shape 270b89df543a7e48e206a2d830c0e10e5265c630.ttf", "സ്റ്റ്").chomp
      assert_equal "[glyph201=0+1183|U0D4D=0+0]", shape
    end
    system python3, "-c", "from gi.repository import HarfBuzz"
  end
  bottle do
    root_url "https://github.com/italoag/homebrew-intel/releases/download/tahoe-bottles"
    sha256 cellar: :any, tahoe: "004ba4f635d0eb2a3e6f345ae4eafc278e8aafa80a2c601030dda20598614994"
  end

end
