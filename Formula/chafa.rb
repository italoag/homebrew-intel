class Chafa < Formula
  desc "Versatile and fast Unicode/ASCII/ANSI graphics renderer"
  homepage "https://hpjansson.org/chafa/"
  url "https://hpjansson.org/chafa/releases/chafa-1.18.3.tar.xz"
  sha256 "fb995ef21dce6c73dd0dd454ba3e0f7fac08e053ea16060a2e5ce69a3746ee27"
  license "LGPL-3.0-or-later"
  compatibility_version 1

  livecheck do
    url "https://hpjansson.org/chafa/releases/?C=M&O=D"
    regex(/href=.*?chafa[._-]v?(\d+(?:\.\d+)+)\.t/i)
  end


  head do
    url "https://github.com/hpjansson/chafa.git", branch: "master"
    depends_on "italoag/intel/autoconf" => :build
    depends_on "italoag/intel/automake" => :build
    depends_on "italoag/intel/libtool" => :build
  end

  depends_on "italoag/intel/pkgconf" => :build
  depends_on "italoag/intel/cairo"
  depends_on "italoag/intel/freetype"
  depends_on "italoag/intel/glib"
  depends_on "italoag/intel/jpeg-turbo"
  depends_on "italoag/intel/jpeg-xl"
  depends_on "italoag/intel/libavif"
  depends_on "italoag/intel/librsvg"
  depends_on "italoag/intel/libtiff"
  depends_on "italoag/intel/webp"

  on_macos do
    depends_on "italoag/intel/gdk-pixbuf"
    depends_on "italoag/intel/gettext"
  end

  deny_network_access!

  def install
    with_env(NOCONFIGURE: "1") { system "./autogen.sh" } if build.head?
    system "./configure", "--disable-silent-rules", *std_configure_args
    system "make", "install"
    man1.install "docs/chafa.1" if build.stable?
  end

  test do
    output = shell_output("#{bin}/chafa #{test_fixtures("test.png")}")
    assert_equal 3, output.lines.count
    output = shell_output("#{bin}/chafa --version")
    assert_match(/Loaders:.* AVIF.* JPEG.* JXL.* SVG.* TIFF.* WebP/, output)
  end
  bottle do
    root_url "https://github.com/italoag/homebrew-intel/releases/download/tahoe-bottles"
    sha256 cellar: :any, tahoe: "93ec265f8eeed8f24eea319a465f94a15d2c8ab3e3df8259107bb23c161a00db"
  end

end
