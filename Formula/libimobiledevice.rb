class Libimobiledevice < Formula
  desc "Library to communicate with iOS devices natively"
  homepage "https://www.libimobiledevice.org/"
  url "https://github.com/libimobiledevice/libimobiledevice/releases/download/1.4.0/libimobiledevice-1.4.0.tar.bz2"
  sha256 "23cc0077e221c7d991bd0eb02150a0d49199bcca1ddf059edccee9ffd914939d"
  license "LGPL-2.1-or-later"
  revision 2
  compatibility_version 1
  head "https://github.com/libimobiledevice/libimobiledevice.git", branch: "master"


  depends_on "italoag/intel/autoconf" => :build
  depends_on "italoag/intel/automake" => :build
  depends_on "italoag/intel/libtool" => :build
  depends_on "italoag/intel/pkgconf" => :build
  depends_on "italoag/intel/libimobiledevice-glue"
  depends_on "italoag/intel/libplist"
  depends_on "italoag/intel/libtasn1"
  depends_on "italoag/intel/libtatsu"
  depends_on "italoag/intel/libusbmuxd"
  depends_on "italoag/intel/openssl@4"

  on_linux do
    depends_on "italoag/intel/readline"
  end

  deny_network_access!

  def install
    # As long as libplist builds without Cython bindings,
    # so should libimobiledevice as well.
    args = %w[
      --disable-silent-rules
      --without-cython
      --enable-debug
    ]

    configure = build.head? ? "./autogen.sh" : "./configure"
    system configure, *args, *std_configure_args
    system "make", "install"
  end

  test do
    system bin/"idevicedate", "--help"
  end
  bottle do
    root_url "https://github.com/italoag/homebrew-intel/releases/download/tahoe-bottles"
    sha256 cellar: :any, tahoe: "e70d96700fad20cd32f2c110db3403fca2dc2f62435d7010fe99bf6910ca984a"
  end

end
