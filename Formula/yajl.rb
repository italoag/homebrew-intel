class Yajl < Formula
  desc "Yet Another JSON Library"
  homepage "https://lloyd.github.io/yajl/"
  url "https://github.com/lloyd/yajl/archive/refs/tags/2.1.0.tar.gz"
  sha256 "3fb73364a5a30efe615046d07e6db9d09fd2b41c763c5f7d3bfb121cd5c5ac5a"
  license "ISC"
  revision 1


  depends_on "italoag/intel/cmake" => :build

  # Upstream is unmaintained so we use Debian patches to fix CVEs and other
  # issues while formula is still used by non-deprecated dependents.
  patch do
    url "https://deb.debian.org/debian/pool/main/y/yajl/yajl_2.1.0-7.debian.tar.xz"
    mirror "https://snapshot.debian.org/archive/debian/20260901T022952Z/pool/main/y/yajl/yajl_2.1.0-7.debian.tar.xz"
    sha256 "9196bd56b2a806d1b9794892dc47e994e5d76feee7a8208ee11d541b7421be78"
    type :unofficial
    apply "patches/dynamically-link-tools.patch",
          "patches/CVE-2017-16516.patch",
          "patches/CVE-2022-24795.patch",
          "patches/CVE-2023-33460.patch",
          "patches/6fe59ca50dfd65bdb3d1c87a27245b2dd1a072f9.patch", # cmake 4
          "patches/non-gcc-visibility-check.patch"
  end

  deny_network_access!

  def install
    ENV.deparallelize

    system "cmake", "-S", ".", "-B", "build", *std_cmake_args
    system "cmake", "--build", "build"
    system "cmake", "--install", "build"
    (include/"yajl").install Dir["src/api/*.h"]
  end

  test do
    output = pipe_output("#{bin}/json_verify", "[0,1,2,3]").strip
    assert_equal "JSON is valid", output
  end
  bottle do
    root_url "https://github.com/italoag/homebrew-intel/releases/download/tahoe-bottles"
    sha256 cellar: :any, tahoe: "710e4550684b569835b436e1decbd7188efe9177eaeb7990e28e9e7ab66a9d5d"
  end

end
