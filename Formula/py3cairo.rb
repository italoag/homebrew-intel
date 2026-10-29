class Py3cairo < Formula
  desc "Python 3 bindings for the Cairo graphics library"
  homepage "https://cairographics.org/pycairo/"
  url "https://github.com/pygobject/pycairo/releases/download/v1.29.2/pycairo-1.29.2.tar.gz"
  sha256 "3e69fff74fe64f5ba2dfa31f67c6bdf26413342574047437d2ac520d35e9a489"
  license any_of: ["LGPL-2.1-only", "MPL-1.1"]
  revision 1
  compatibility_version 1


  depends_on "italoag/intel/meson" => :build
  depends_on "italoag/intel/ninja" => :build
  depends_on "italoag/intel/pkgconf" => :build
  depends_on "italoag/intel/python@3.14" => [:build, :test]
  depends_on "italoag/intel/python@3.15" => [:build, :test]
  depends_on "italoag/intel/cairo"

  def pythons
    deps.map(&:to_formula)
        .select { |f| f.name.match?(/^python@\d\.\d+$/) }
        .map { |f| f.opt_libexec/"bin/python" }
  end

  def site_packages(python)
    prefix/Language::Python.site_packages(python)
  end

  def install
    pythons.each do |python|
      python_version = Language::Python.major_minor_version(python)
      builddir = "build#{python_version}"
      system "meson", "setup", builddir, "-Dpython=#{python}",
                                         "-Dpython.platlibdir=#{site_packages(python)}",
                                         "-Dpython.purelibdir=#{site_packages(python)}",
                                         *std_meson_args
      system "meson", "compile", "-C", builddir
      system "meson", "install", "-C", builddir
    end
  end

  test do
    pythons.each do |python|
      system python, "-c", "import cairo; print(cairo.version)"
    end
  end
  bottle do
    root_url "https://github.com/italoag/homebrew-intel/releases/download/tahoe-bottles"
    sha256 cellar: :any, tahoe: "0cba0df9d6dfa9a30d30263f7bf2d54563b6e484a1e7798f320fd129c613b13d"
  end

end
