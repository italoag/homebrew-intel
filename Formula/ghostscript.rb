class Ghostscript < Formula
  desc "Interpreter for PostScript and PDF"
  homepage "https://www.ghostscript.com/"
  url "https://github.com/ArtifexSoftware/ghostpdl-downloads/releases/download/gs10080/ghostpdl-10.08.0.tar.xz"
  sha256 "94943e3c4adb7115d132b3c28b913672f2e62e6a9d802f7e754e716b1634174a"
  license "AGPL-3.0-or-later"
  compatibility_version 1

  # The GitHub tags omit delimiters (e.g. `gs9533` for version 9.53.3). The
  # `head` repository tags are formatted fine (e.g. `ghostpdl-9.53.3`) but a
  # version may be tagged before the release is available on GitHub, so we
  # check the version from the first-party website instead.
  livecheck do
    url "https://www.ghostscript.com/json/settings.json"
    strategy :json do |json|
      json["GS_VER"]
    end
  end


  head do
    url "https://github.com/ArtifexSoftware/ghostpdl.git", branch: "master"

    depends_on "italoag/intel/autoconf" => :build
    depends_on "italoag/intel/automake" => :build
    depends_on "italoag/intel/libtool" => :build
  end

  depends_on "italoag/intel/pkgconf" => :build
  depends_on "italoag/intel/fontconfig"
  depends_on "italoag/intel/freetype"
  depends_on "italoag/intel/jbig2dec"
  depends_on "italoag/intel/jpeg-turbo"
  depends_on "italoag/intel/leptonica"
  depends_on "italoag/intel/libarchive"
  depends_on "italoag/intel/libidn"
  depends_on "italoag/intel/libpng"
  depends_on "italoag/intel/libtiff"
  depends_on "italoag/intel/little-cms2"
  depends_on "italoag/intel/openjpeg"
  depends_on "italoag/intel/tesseract"

  uses_from_macos "expat"

  on_linux do
    depends_on "zlib-ng-compat"
  end

  conflicts_with "gambit-scheme", because: "both install `gsc` binary"
  conflicts_with "gerbil-scheme", because: "both install `gsc` binary"

  # https://sourceforge.net/projects/gs-fonts/
  resource "fonts" do
    url "https://downloads.sourceforge.net/project/gs-fonts/gs-fonts/8.11%20%28base%2035%2C%20GPL%29/ghostscript-fonts-std-8.11.tar.gz"
    sha256 "0eb6f356119f2e49b2563210852e17f57f9dcc5755f350a69a46a0d641a0c401"
  end

  deny_network_access!

  def install
    # Delete local vendored sources so build uses system dependencies
    libs = %w[expat freetype jbig2dec jpeg lcms2mt leptonica libpng openjpeg tesseract tiff zlib]
    libs.each { |l| rm_r(buildpath/l) }

    configure = build.head? ? "./autogen.sh" : "./configure"

    args = %w[--disable-compile-inits
              --disable-cups
              --disable-gtk
              --with-system-libtiff
              --without-versioned-path
              --without-x]

    # Set the correct library install names so that `brew` doesn't need to fix them up later.
    ENV["DARWIN_LDFLAGS_SO_PREFIX"] = "#{opt_lib}/"
    ENV.append_to_cflags "-fPIC" if OS.linux?
    ENV["XCFLAGS"] = ENV.cflags
    ENV["XCXXFLAGS"] = ENV.cxxflags

    system configure, *args, *std_configure_args

    # Install binaries and libraries
    system "make", "install"
    ENV.deparallelize { system "make", "install-so" }

    (pkgshare/"fonts").install resource("fonts")
  end

  def caveats
    <<~CAVEATS
      Ghostscript is now built `--without-versioned-path`. Temporary backwards
      compatibility symlinks exist but will be removed with 10.07.0 release.
    CAVEATS
  end

  test do
    ps = test_fixtures("test.ps")
    assert_match "Hello World!", shell_output("#{bin}/ps2ascii #{ps}")
  end
  bottle do
    root_url "https://github.com/italoag/homebrew-intel/releases/download/tahoe-bottles"
    sha256 tahoe: "14ff6fc70a102ed49133532b474ab9011e01b1ac212b8973ded8acadcd684b69"
  end

end
