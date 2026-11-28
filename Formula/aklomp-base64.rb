class AklompBase64 < Formula
  desc "Fast Base64 stream encoder/decoder in C99, with SIMD acceleration"
  homepage "https://github.com/aklomp/base64"
  url "https://github.com/aklomp/base64/archive/refs/tags/v0.5.3.tar.gz"
  sha256 "74f83a5396660dfe5a09f0339982c03c44ef018e459a8bfcde8b31ca7444aa42"
  license "BSD-2-Clause"
  compatibility_version 1


  depends_on "italoag/intel/cmake" => :build

  conflicts_with "base64", because: "both install `base64` binaries"

  deny_network_access!

  def install
    system "cmake", "-S", ".", "-B", "build",
                    "-DBUILD_SHARED_LIBS=ON",
                    "-DCMAKE_INSTALL_RPATH=#{rpath}",
                    *std_cmake_args
    system "cmake", "--build", "build"
    system "cmake", "--install", "build"
  end

  test do
    assert_equal "aGVsbG8=", pipe_output(bin/"base64", "hello", 0).strip
  end
  bottle do
    root_url "https://github.com/italoag/homebrew-intel/releases/download/tahoe-bottles"
    sha256 cellar: :any, tahoe: "1ea4dd61b8486eb79db4bf5926bd210e9f9e1e259d2ac78f11eb9cc618c38528"
  end

end
