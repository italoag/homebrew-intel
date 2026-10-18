class Libvmaf < Formula
  desc "Perceptual video quality assessment based on multi-method fusion"
  homepage "https://github.com/Netflix/vmaf"
  url "https://github.com/Netflix/vmaf/archive/refs/tags/v3.2.1.tar.gz"
  sha256 "5df7386911bc15fd1ca783132528748d219768ae4fc5f8e0b61184f041648092"
  license "BSD-2-Clause-Patent"
  compatibility_version 1

  bottle do
    root_url "https://github.com/italoag/homebrew-intel/releases/download/tahoe-bottles"
    sha256 cellar: :any, tahoe: "0e43f9720aa357a886884db970b22d66804e1b8d9623abebf8a78536c2a6e2e8"
  end


  depends_on "meson" => :build
  depends_on "ninja" => :build
  uses_from_macos "vim" => :build # needed for xxd

  on_intel do
    depends_on "nasm" => :build
  end

  def install
    system "meson", "setup", "build", "libvmaf", *std_meson_args
    system "meson", "compile", "-C", "build", "--verbose"
    system "meson", "install", "-C", "build"
    pkgshare.install "model"
  end

  test do
    (testpath/"test.c").write <<~C
      #include <libvmaf/libvmaf.h>
      int main() {
        return 0;
      }
    C

    flags = [
      "-I#{HOMEBREW_PREFIX}/include/libvmaf",
      "-L#{lib}",
    ]

    system ENV.cc, "test.c", "-o", "test", *flags
    system "./test"
  end
end
