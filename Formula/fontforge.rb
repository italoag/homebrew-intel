class Fontforge < Formula
  desc "Command-line outline and bitmap font editor/converter"
  homepage "https://fontforge.github.io"
  url "https://github.com/fontforge/fontforge/releases/download/20251009/fontforge-20251009.tar.xz"
  sha256 "69046500185a5581b58139dfad30c0b3d8128f00ebbfddc31f2fcf877e329e52"
  license "GPL-3.0-or-later"
  revision 2
  compatibility_version 1
  head "https://github.com/fontforge/fontforge.git", branch: "master"


  depends_on "italoag/intel/cmake" => :build
  depends_on "italoag/intel/gettext" => :build
  depends_on "italoag/intel/ninja" => :build
  depends_on "italoag/intel/pkgconf" => :build

  depends_on "italoag/intel/cairo"
  depends_on "italoag/intel/fontconfig"
  depends_on "italoag/intel/freetype"
  depends_on "italoag/intel/giflib"
  depends_on "italoag/intel/glib"
  depends_on "italoag/intel/jpeg-turbo"
  depends_on "italoag/intel/libpng"
  depends_on "italoag/intel/libspiro"
  depends_on "italoag/intel/libtiff"
  depends_on "italoag/intel/libtool"
  depends_on "italoag/intel/libuninameslist"
  depends_on "italoag/intel/pango"
  depends_on "italoag/intel/python@3.15"
  depends_on "italoag/intel/readline"
  depends_on "italoag/intel/woff2"

  uses_from_macos "libxml2"

  on_macos do
    depends_on "italoag/intel/brotli"
    depends_on "italoag/intel/gettext"
  end

  on_linux do
    depends_on "zlib-ng-compat"
  end

  resource "homebrew-testdata", :test do
    url "https://raw.githubusercontent.com/fontforge/fontforge/1346ce6e4c004c312589fdb67e31d4b2c32a1656/tests/fonts/Ambrosia.sfd"
    sha256 "6a22acf6be4ab9e5c5a3373dc878030b4b8dc4652323395388abe43679ceba81"
  end

  allow_network_access! :test

  def install
    args = %W[
      -DENABLE_GUI=OFF
      -DENABLE_FONTFORGE_EXTRAS=ON
      -DPython3_EXECUTABLE=#{python3}
      -DPYHOOK_INSTALL_DIR=#{Language::Python.site_packages(python3)}
    ]

    system "cmake", "-S", ".", "-B", "build", *args, *std_cmake_args
    system "cmake", "--build", "build"
    system "cmake", "--install", "build"
  end

  def caveats
    on_macos do
      <<~TEXT
        This formula only installs the command line utilities.

        FontForge.app can be downloaded directly from the website:
          https://fontforge.github.io

        Alternatively, install with Homebrew Cask:
          brew install --cask fontforge
      TEXT
    end
  end

  test do
    system bin/"fontforge", "-version"
    system bin/"fontforge", "-lang=py", "-c", "import fontforge; fontforge.font()"
    system python3, "-c", "import fontforge; fontforge.font()"

    resource("homebrew-testdata").stage do
      ffscript = "fontforge.open('Ambrosia.sfd').generate('#{testpath}/Ambrosia.woff2')"
      system bin/"fontforge", "-c", ffscript
    end
    assert_path_exists testpath/"Ambrosia.woff2"

    fileres = shell_output("/usr/bin/file #{testpath}/Ambrosia.woff2")
    assert_match "Web Open Font Format (Version 2)", fileres
  end
  bottle do
    root_url "https://github.com/italoag/homebrew-intel/releases/download/tahoe-bottles"
    sha256 tahoe: "fa93788fbcfe9850d102c06968b2b647b332191d903ba4e8b197ab45e2d64694"
  end

end
