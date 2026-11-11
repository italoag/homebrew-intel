class Libtatsu < Formula
  desc "Library handling the communication with Apple's Tatsu Signing Server (TSS)"
  homepage "https://libimobiledevice.org/"
  url "https://github.com/libimobiledevice/libtatsu/releases/download/1.1.0/libtatsu-1.1.0.tar.bz2"
  sha256 "96c8abd97552a4a0c487c701aba9a65d590c338dd331058ffb38304290b696c7"
  license "LGPL-2.1-or-later"
  compatibility_version 1
  head "https://github.com/libimobiledevice/libtatsu.git", branch: "master"


  depends_on "italoag/intel/autoconf" => :build
  depends_on "italoag/intel/automake" => :build
  depends_on "italoag/intel/libtool" => :build
  depends_on "italoag/intel/pkgconf" => :build
  depends_on "italoag/intel/libplist"

  uses_from_macos "curl"

  deny_network_access!

  def install
    configure = build.head? ? "./autogen.sh" : "./configure"
    system configure, "--disable-silent-rules", *std_configure_args
    system "make", "install"
  end

  test do
    (testpath/"test.c").write <<~C
      #include "libtatsu/tss.h"

      int main(int argc, char* argv[]) {
        tss_set_debug_level(0);
        return 0;
      }
    C
    system ENV.cc, "test.c", "-L#{lib}", "-ltatsu", "-o", "test"
    system "./test"
  end
  bottle do
    root_url "https://github.com/italoag/homebrew-intel/releases/download/tahoe-bottles"
    sha256 cellar: :any, tahoe: "635f6a9e2112c0358ac368e0cbdffbb56657bdb2889087d9942febafb7802ea8"
  end

end
