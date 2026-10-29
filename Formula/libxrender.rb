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
  bottle do
    root_url "https://github.com/italoag/homebrew-intel/releases/download/tahoe-bottles"
    sha256 cellar: :any, tahoe: "68938f6828ff63e8a61906139338d89bc836aaa2f5b00334136c3c9797c903c9"
  end

end
