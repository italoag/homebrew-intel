class Libxrender < Formula
  desc "X.Org: Library for the Render Extension to the X11 protocol"
  homepage "https://www.x.org/"
  url "https://xorg.freedesktop.org/archive/individual/lib/libXrender-0.9.13.tar.gz"
  sha256 "bf264b683d1e49ff9a6bc03af13baa430a556d943731a2b1ac2439dae4fea205"
  license "MIT"
  compatibility_version 1


  depends_on "italoag/intel/pkgconf" => :build
  depends_on "italoag/intel/libx11"
  depends_on "italoag/intel/xorgproto"

  deny_network_access!

  def install
    args = %W[
      --sysconfdir=#{etc}
      --localstatedir=#{var}
      --disable-silent-rules
    ]

    system "./configure", *args, *std_configure_args
    system "make"
    system "make", "install"
  end

  test do
    (testpath/"test.c").write <<~C
      #include "X11/Xlib.h"
      #include "X11/extensions/Xrender.h"

      int main(int argc, char* argv[]) {
        XRenderColor color;
        return 0;
      }
    C
    system ENV.cc, "test.c"
  end
  bottle do
    root_url "https://github.com/italoag/homebrew-intel/releases/download/tahoe-bottles"
    sha256 cellar: :any, tahoe: "88194c8f8b7c9d929cf6a3b539f0449d85e66c96113852112b0529652d9bbe1b"
  end

end
