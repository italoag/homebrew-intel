class Libtatsu < Formula
  desc "Library handling the communication with Apple's Tatsu Signing Server (TSS)"
  homepage "https://libimobiledevice.org/"
  url "https://github.com/libimobiledevice/libtatsu/releases/download/1.0.5/libtatsu-1.0.5.tar.bz2"
  sha256 "536fa228b14f156258e801a7f4d25a3a9dd91bb936bf6344e23171403c57e440"
  license "LGPL-2.1-or-later"
  revision 1
  head "https://github.com/libimobiledevice/libtatsu.git", branch: "master"

  bottle do
    root_url "https://github.com/italoag/homebrew-intel/releases/download/tahoe-bottles"
    sha256 cellar: :any, tahoe: "c372a224319f4ca7ccd75546c00a96a9af893f5171b2fb87362b1c9e83fb0366"
  end


  depends_on "autoconf" => :build
  depends_on "automake" => :build
  depends_on "libtool" => :build
  depends_on "pkgconf" => :build
  depends_on "libplist"

  uses_from_macos "curl"

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
end
