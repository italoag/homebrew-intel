class Libimobiledevice < Formula
  desc "Library to communicate with iOS devices natively"
  homepage "https://www.libimobiledevice.org/"
  license "LGPL-2.1-or-later"
  revision 3
  compatibility_version 1
  head "https://github.com/libimobiledevice/libimobiledevice.git", branch: "master"

  stable do
    url "https://github.com/libimobiledevice/libimobiledevice/releases/download/1.4.0/libimobiledevice-1.4.0.tar.bz2"
    sha256 "23cc0077e221c7d991bd0eb02150a0d49199bcca1ddf059edccee9ffd914939d"

    # Backport fix for an unbounded memory leak in the ostrace code path.
    # https://github.com/libimobiledevice/libimobiledevice/issues/1677
    patch do
      url "https://github.com/libimobiledevice/libimobiledevice/commit/5ca453f9e3950b1f24b51e4cdf255236e34254c4.patch?full_index=1"
      sha256 "f77230cd1be4b483e0e0bc1273c25a273fb3845d7e65831f0b62d1a5f0f01a83"
      type :backport
      resolves "https://github.com/libimobiledevice/libimobiledevice/issues/1677"
    end
  end


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
    sha256 cellar: :any, tahoe: "eb255b2da23caa3efb7703375da2963d9350b555fad3f59d9d5276173dd5f2b7"
  end

end
