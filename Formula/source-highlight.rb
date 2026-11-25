class SourceHighlight < Formula
  desc "Source-code syntax highlighter"
  homepage "https://www.gnu.org/software/src-highlite/"
  url "https://ftpmirror.gnu.org/src-highlite/source-highlight-3.1.9.tar.gz"
  mirror "https://ftp.gnu.org/gnu/src-highlite/source-highlight-3.1.9.tar.gz"
  sha256 "3a7fd28378cb5416f8de2c9e77196ec915145d44e30ff4e0ee8beb3fe6211c91"
  license "GPL-3.0-or-later"
  revision 7
  compatibility_version 1

  livecheck do
    url :stable
    regex(/href=.*?source-highlight[._-]v?(\d+(?:\.\d+)+)\.t/i)
  end


  depends_on "italoag/intel/boost" => :no_linkage

  # Fix -flat_namespace being used on Big Sur and later.
  patch do
    file "Patches/libtool/configure-big_sur.diff"
    type :unofficial
  end

  deny_network_access!

  def install
    ENV.cxx11
    ENV.append "LDFLAGS", "-Wl,-dead_strip_dylibs" if OS.mac? # strip boost linkage

    system "./configure", "--with-boost=#{formula_opt_prefix("boost")}", *std_configure_args
    system "make", "install"

    bash_completion.install "completion/source-highlight"
  end

  test do
    assert_match "GNU Source-highlight #{version}", shell_output("#{bin}/source-highlight -V")
  end
  bottle do
    root_url "https://github.com/italoag/homebrew-intel/releases/download/tahoe-bottles"
    sha256 tahoe: "ae0124e5175955ee5fdf0f79117d5cfe64762d6c6823616ae1b09ea667fa1897"
  end

end
