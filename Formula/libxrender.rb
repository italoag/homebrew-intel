class Libxrender < Formula
  desc "X.Org: Library for the Render Extension to the X11 protocol"
  homepage "https://www.x.org/"
  url "https://xorg.freedesktop.org/archive/individual/lib/libXrender-0.9.13.tar.gz"
  sha256 "bf264b683d1e49ff9a6bc03af13baa430a556d943731a2b1ac2439dae4fea205"
  license "MIT"
  compatibility_version 1

  bottle do
    root_url "https://github.com/italoag/homebrew-intel/releases/download/tahoe-bottles"
    sha256 cellar: :any, tahoe: "2c415b9bad0b396e9bd065c43d36d5482e5de8c2cd34faf949f10f5a9d671da6"
  end


  depends_on "pkgconf" => :build
  depends_on "libx11"
  depends_on "xorgproto"

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
    assert_equal 0, $CHILD_STATUS.exitstatus
  end
end
