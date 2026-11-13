class Poppler < Formula
  desc "PDF rendering library (based on the xpdf-3.0 code base)"
  homepage "https://poppler.freedesktop.org/"
  url "https://poppler.freedesktop.org/poppler-26.11.0.tar.xz"
  sha256 "41c32680160addf5a8dd7a830e4869c01e9f6bee1abb91e44fabd1ba9d7828fb"
  license any_of: ["GPL-2.0-only", "GPL-3.0-only"] # see README-XPDF
  compatibility_version 9
  head "https://gitlab.freedesktop.org/poppler/poppler.git", branch: "master"

  livecheck do
    url :homepage
    regex(/href=.*?poppler[._-]v?(\d+(?:\.\d+)+)\.t/i)
  end


  depends_on "italoag/intel/cmake" => :build
  depends_on "italoag/intel/gettext" => :build
  depends_on "italoag/intel/gobject-introspection" => :build
  depends_on "italoag/intel/pkgconf" => :build

  depends_on "italoag/intel/brotli"
  depends_on "italoag/intel/cairo"
  depends_on "italoag/intel/fontconfig"
  depends_on "italoag/intel/freetype"
  depends_on "italoag/intel/glib"
  depends_on "italoag/intel/gpgmepp"
  depends_on "italoag/intel/harfbuzz"
  depends_on "italoag/intel/jpeg-turbo"
  depends_on "italoag/intel/libpng"
  depends_on "italoag/intel/libtiff"
  depends_on "italoag/intel/little-cms2"
  depends_on "italoag/intel/nspr"
  depends_on "italoag/intel/nss"
  depends_on "italoag/intel/openjpeg"

  uses_from_macos "gperf" => :build
  uses_from_macos "curl", since: :sonoma # needs curl >= 8.5

  on_macos do
    depends_on "italoag/intel/gettext"
    depends_on "italoag/intel/gpgme"
  end

  on_linux do
    depends_on "zlib-ng-compat"
  end

  conflicts_with "pdftohtml", "pdf2image", "xpdf",
    because: "poppler, pdftohtml, pdf2image, and xpdf install conflicting executables"

  resource "font-data" do
    url "https://poppler.freedesktop.org/poppler-data-0.4.12.tar.gz"
    sha256 "c835b640a40ce357e1b83666aabd95edffa24ddddd49b8daff63adb851cdab74"

    livecheck do
      url "https://poppler.freedesktop.org/"
      regex(/href=.*?poppler-data[._-]v?(\d+(?:\.\d+)+)\.t/i)
    end
  end

  deny_network_access!

  def install
    args = std_cmake_args + %W[
      -DBUILD_GTK_TESTS=OFF
      -DENABLE_BOOST=OFF
      -DENABLE_GLIB=ON
      -DENABLE_QT5=OFF
      -DENABLE_QT6=OFF
      -DENABLE_UNSTABLE_API_ABI_HEADERS=ON
      -DWITH_GObjectIntrospection=ON
      -DCMAKE_INSTALL_RPATH=#{rpath}
    ]

    system "cmake", "-S", ".", "-B", "build_shared", *args
    system "cmake", "--build", "build_shared"
    system "cmake", "--install", "build_shared"

    system "cmake", "-S", ".", "-B", "build_static", *args, "-DBUILD_SHARED_LIBS=OFF"
    system "cmake", "--build", "build_static"
    lib.install "build_static/libpoppler.a"
    lib.install "build_static/cpp/libpoppler-cpp.a"
    lib.install "build_static/glib/libpoppler-glib.a"

    # Add extra metafiles for licensing information
    prefix.install "COPYING3", "README-XPDF"

    resource("font-data").stage do
      system "make", "install", "prefix=#{prefix}"
    end
  end

  test do
    system bin/"pdfinfo", test_fixtures("test.pdf")
  end
  bottle do
    root_url "https://github.com/italoag/homebrew-intel/releases/download/tahoe-bottles"
    sha256 tahoe: "9cdebaa710af5a659fbc055d118d64074970e99d1d4f38bd8d20c59833c6356e"
  end

end
