class Gtk4 < Formula
  desc "Toolkit for creating graphical user interfaces"
  homepage "https://gtk.org/"
  url "https://download.gnome.org/sources/gtk/4.24/gtk-4.24.2.tar.xz"
  sha256 "05561abc25d1b1400136bf79ab68830cb4b053d1922ae97e551b3f19755bf3cb"
  license "LGPL-2.1-or-later"
  compatibility_version 1
  head "https://gitlab.gnome.org/GNOME/gtk.git", branch: "main"

  livecheck do
    url :stable
    regex(/gtk[._-](4\.([0-8]\d*?)?[02468](?:\.\d+)*?)\.t/i)
  end


  depends_on "italoag/intel/dart-sass" => :build
  depends_on "italoag/intel/docbook" => :build
  depends_on "italoag/intel/docbook-xsl" => :build
  depends_on "italoag/intel/docutils" => :build
  depends_on "italoag/intel/gettext" => :build
  depends_on "italoag/intel/gobject-introspection" => :build
  depends_on "italoag/intel/meson" => :build
  depends_on "italoag/intel/ninja" => :build
  depends_on "italoag/intel/pkgconf" => [:build, :test]
  depends_on "italoag/intel/cairo"
  depends_on "italoag/intel/fontconfig"
  depends_on "italoag/intel/fribidi"
  depends_on "italoag/intel/gdk-pixbuf"
  depends_on "italoag/intel/glib"
  depends_on "italoag/intel/graphene"
  depends_on "italoag/intel/harfbuzz"
  depends_on "italoag/intel/hicolor-icon-theme"
  depends_on "italoag/intel/jpeg-turbo"
  depends_on "italoag/intel/libepoxy"
  depends_on "italoag/intel/libpng"
  depends_on "italoag/intel/librsvg"
  depends_on "italoag/intel/libtiff"
  depends_on "italoag/intel/pango"

  uses_from_macos "libxslt" => :build # for xsltproc
  uses_from_macos "cups"

  on_macos do
    depends_on "italoag/intel/gettext"
  end

  on_linux do
    depends_on "wayland-protocols" => :build
    depends_on "italoag/intel/libx11"
    depends_on "libxcursor"
    depends_on "libxdamage"
    depends_on "italoag/intel/libxext"
    depends_on "libxfixes"
    depends_on "libxi"
    depends_on "libxinerama"
    depends_on "libxkbcommon"
    depends_on "libxrandr"
    depends_on "wayland"
  end

  deny_network_access!

  def install
    # Replace deprecated `sassc` with `sass` in the meson build file
    inreplace "gtk/meson.build" do |s|
      s.gsub! "'sassc'", "'sass'"
      s.gsub! "'-a', '-M', '-t', 'compact'", "'--style', 'compressed'"
    end
    inreplace "build-aux/meson/dist-data.py", "'-a', '-M', '-t', 'compact'", "'--style', 'compressed'"

    args = %w[
      -Dbuild-examples=false
      -Dbuild-tests=false
      -Dintrospection=enabled
      -Dman-pages=true
      -Dmedia-gstreamer=disabled
      -Dvulkan=disabled
    ]

    if OS.mac?
      args << "-Dx11-backend=false"
      args << "-Dmacos-backend=true"
    end

    # ensure that we don't run the meson post install script
    ENV["DESTDIR"] = "/"

    # Find our docbook catalog
    ENV["XML_CATALOG_FILES"] = "#{etc}/xml/catalog"

    # Disable asserts and cast checks explicitly
    ENV.append "CPPFLAGS", "-DG_DISABLE_ASSERT -DG_DISABLE_CAST_CHECKS"

    system "meson", "setup", "build", *args, *std_meson_args
    system "meson", "compile", "-C", "build", "--verbose"
    system "meson", "install", "-C", "build"
  end

  post_install_steps do
    compile_gsettings_schemas
    update_gtk_icon_cache
  end

  test do
    (testpath/"test.c").write <<~C
      #include <gtk/gtk.h>

      int main(int argc, char *argv[]) {
        gtk_disable_setlocale();
        return 0;
      }
    C

    flags = shell_output("#{formula_opt_bin("pkgconf")}/pkgconf --cflags --libs gtk4").strip.split
    system ENV.cc, "test.c", "-o", "test", *flags
    system "./test"
    # include a version check for the pkg-config files
    assert_match version.to_s, shell_output("cat #{lib}/pkgconfig/gtk4.pc").strip
  end
  bottle do
    root_url "https://github.com/italoag/homebrew-intel/releases/download/tahoe-bottles"
    sha256 tahoe: "53d3066b5b17ee2d2d0fa30d11fe34c97ab10447e163711f17a473c345a51635"
  end

end
