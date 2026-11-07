class Libuninameslist < Formula
  desc "Library of Unicode names and annotation data"
  homepage "https://github.com/fontforge/libuninameslist"
  url "https://github.com/fontforge/libuninameslist/releases/download/20260918/libuninameslist-dist-20260918.tar.gz"
  sha256 "deb2ec02640c232a4bc333c2cd301ee6b286914eeeb0ccc31ccafe326aed0029"
  license "BSD-3-Clause"
  compatibility_version 1

  livecheck do
    url :stable
    regex(/v?(\d+(?:\.\d+)*)/i)
    strategy :github_latest
  end


  head do
    url "https://github.com/fontforge/libuninameslist.git", branch: "master"

    depends_on "italoag/intel/autoconf" => :build
    depends_on "italoag/intel/automake" => :build
    depends_on "italoag/intel/libtool" => :build
  end

  deny_network_access!

  def install
    if build.head?
      system "autoreconf", "--force", "--install", "--verbose"
      system "automake"
    end

    system "./configure", "--prefix=#{prefix}"
    system "make", "install"
  end

  test do
    (testpath/"test.c").write <<~C
      #include <uninameslist.h>

      int main() {
        (void)uniNamesList_blockCount();
        return 0;
      }
    C
    system ENV.cc, "test.c", "-I#{include}", "-L#{lib}", "-luninameslist", "-o", "test"
    system "./test"
  end
  bottle do
    root_url "https://github.com/italoag/homebrew-intel/releases/download/tahoe-bottles"
    sha256 cellar: :any, tahoe: "c112d1ccb72bc619326ef7ebf6c1a35da401ba64788fb3912fe75bb7a8d69ad2"
  end

end
