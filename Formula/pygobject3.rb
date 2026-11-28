class Pygobject3 < Formula
  desc "GNOME Python bindings (based on GObject Introspection)"
  homepage "https://pygobject.gnome.org"
  url "https://download.gnome.org/sources/pygobject/3.58/pygobject-3.58.1.tar.gz"
  sha256 "4c80598ade17fbaa7798e01a25d0bf29ce109740786026a074c5c62bb3e79d23"
  license "LGPL-2.1-or-later"
  revision 1
  compatibility_version 1


  depends_on "italoag/intel/meson" => :build
  depends_on "italoag/intel/ninja" => :build
  depends_on "italoag/intel/pkgconf" => :build
  depends_on "italoag/intel/python@3.14" => [:build, :test]
  depends_on "italoag/intel/python@3.15" => [:build, :test]

  depends_on "italoag/intel/cairo"
  depends_on "italoag/intel/glib"
  depends_on "italoag/intel/gobject-introspection"
  depends_on "italoag/intel/py3cairo"

  uses_from_macos "italoag/intel/libffi"

  deny_network_access!

  def install
    python3_interpreters.each do |python|
      xy = Language::Python.major_minor_version(python)
      builddir = "buildpy#{xy}".delete(".")
      site_packages = prefix/Language::Python.site_packages(python)

      system "meson", "setup", builddir, "-Dpycairo=enabled",
                                         "-Dpython=#{python}",
                                         "-Dpython.platlibdir=#{site_packages}",
                                         "-Dpython.purelibdir=#{site_packages}",
                                         "-Dtests=false",
                                         *std_meson_args
      system "meson", "compile", "-C", builddir, "--verbose"
      system "meson", "install", "-C", builddir
    end
  end

  test do
    Pathname("test.py").write <<~PYTHON
      import gi
      gi.require_version("GLib", "2.0")
      assert("__init__" in gi.__file__)
      from gi.repository import GLib
      assert(31 == GLib.Date.get_days_in_month(GLib.DateMonth.JANUARY, 2000))
    PYTHON

    python3_interpreters.each do |python|
      system python, "test.py"
    end
  end
  bottle do
    root_url "https://github.com/italoag/homebrew-intel/releases/download/tahoe-bottles"
    sha256 cellar: :any, tahoe: "3d00228986a657ebace54b7db11ab315203733b4b5b2c249a63773c48d4ef6c7"
  end

end
