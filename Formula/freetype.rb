class Freetype < Formula
  desc "Software library to render fonts"
  homepage "https://www.freetype.org/"
  url "https://downloads.sourceforge.net/project/freetype/freetype2/2.15.0/freetype-2.15.0.tar.xz"
  mirror "https://download.savannah.gnu.org/releases/freetype/freetype-2.15.0.tar.xz"
  sha256 "93cd47eb719c325107f2d3cf087d06299e944c3b48a40b55537302304dea1dd5"
  license "FTL"
  compatibility_version 1

  livecheck do
    url :stable
    regex(/url=.*?freetype[._-]v?(\d+(?:\.\d+)+)\.t/i)
  end

  bottle do
    root_url "https://github.com/italoag/homebrew-intel/releases/download/tahoe-bottles"
    sha256 cellar: :any, tahoe: "5255f92a5b997e9ec65d3333c7729a931da6111a48241d6ff03adc66b7a97bda"
  end


  depends_on "pkgconf" => :build
  depends_on "brotli"
  depends_on "libpng"

  uses_from_macos "bzip2"

  on_linux do
    depends_on "zlib-ng-compat"
  end

  deny_network_access!

  def install
    # This file will be installed to bindir, so we want to avoid embedding the
    # absolute path to the pkg-config shim.
    inreplace "builds/unix/freetype-config.in", "%PKG_CONFIG%", "pkg-config"

    system "./configure", "--prefix=#{prefix}",
                          "--enable-freetype-config",
                          "--with-brotli",
                          "--without-harfbuzz"
    system "make"
    system "make", "install"

    inreplace [bin/"freetype-config", lib/"pkgconfig/freetype2.pc"],
      prefix, opt_prefix
  end

  test do
    system bin/"freetype-config", "--cflags", "--libs", "--ftversion",
                                  "--exec-prefix", "--prefix"
  end
end
